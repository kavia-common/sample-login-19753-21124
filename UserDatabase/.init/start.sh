#!/usr/bin/env bash
set -euo pipefail
# start: launch frontend and backend helper scripts (managed background)
# Uses authoritative workspace path from container info
WS="/home/kavia/workspace/code-generation/sample-login-19753-21124/UserDatabase"
LOGDIR=/tmp/userdb_run_logs
mkdir -p "$LOGDIR"
# ensure workspace exists
if [ ! -d "$WS" ]; then
  echo "ERROR: workspace not found: $WS" >&2
  exit 2
fi
# start backend (force HTTP-only to avoid HTTPS cert interactions)
cd "$WS"
ASPNETCORE_URLS="http://0.0.0.0:5000" nohup setsid "$WS/start-backend.sh" >"$LOGDIR/backend.log" 2>&1 &
BPID=$!
sleep 0.5
BPGID=$(ps -o pgid= "$BPID" | tr -d ' ' || true)
# record control files for operator
echo "$BPID" >"$LOGDIR/backend.pid" || true
echo "$BPGID" >"$LOGDIR/backend.pgid" || true
# start frontend
nohup setsid "$WS/start-frontend.sh" >"$LOGDIR/frontend.log" 2>&1 &
FPID=$!
sleep 0.5
FPGID=$(ps -o pgid= "$FPID" | tr -d ' ' || true)
echo "$FPID" >"$LOGDIR/frontend.pid" || true
echo "$FPGID" >"$LOGDIR/frontend.pgid" || true
# brief status output
echo "backend pid:$BPID pgid:${BPGID:-unknown} frontend pid:$FPID pgid:${FPGID:-unknown}"
