#!/usr/bin/env bash
set -euo pipefail
# validation: build backend, start backend+frontend (HTTP only), poll health endpoints, stop cleanly
WS="/home/kavia/workspace/code-generation/sample-login-19753-21124/UserDatabase"
LOGDIR=/tmp/userdb_validation_logs
mkdir -p "$LOGDIR"
TIMEOUT_SECS=${VALIDATION_TIMEOUT_SECS:-30}
export ASPNETCORE_URLS="http://0.0.0.0:5000"
# build backend
cd "$WS/backend"
dotnet build --nologo --verbosity minimal
# start backend (background, capture logs)
cd "$WS"
setsid bash -c 'ASPNETCORE_URLS="http://0.0.0.0:5000" "'$WS'/start-backend.sh"' >"$LOGDIR/backend.log" 2>&1 &
BACK_PID=$!
# wait for PGID
BACK_PGID=""
for i in 1 10; do
  BACK_PGID=$(ps -o pgid= "$BACK_PID" 2>/dev/null | tr -d ' ' || true)
  [ -n "$BACK_PGID" ] && break || sleep 0.2
done
# start frontend
setsid bash -c '"'$WS'/start-frontend.sh"' >"$LOGDIR/frontend.log" 2>&1 &
FE_PID=$!
FE_PGID=""
for i in 1 10; do
  FE_PGID=$(ps -o pgid= "$FE_PID" 2>/dev/null | tr -d ' ' || true)
  [ -n "$FE_PGID" ] && break || sleep 0.2
done
# cleanup helper
cleanup() {
  # try PGID kill if numeric, else kill PID
  if [[ -n "${BACK_PGID:-}" && "$BACK_PGID" =~ ^[0-9]+$ ]]; then
    kill -TERM -"$BACK_PGID" 2>/dev/null || true
  elif [ -n "${BACK_PID:-}" ]; then
    kill -TERM "$BACK_PID" 2>/dev/null || true
  fi
  if [[ -n "${FE_PGID:-}" && "$FE_PGID" =~ ^[0-9]+$ ]]; then
    kill -TERM -"$FE_PGID" 2>/dev/null || true
  elif [ -n "${FE_PID:-}" ]; then
    kill -TERM "$FE_PID" 2>/dev/null || true
  fi
  # short grace period
  sleep 1
  # ensure termination; kill by PID if still alive
  if [ -n "${BACK_PID:-}" ]; then
    if kill -0 "$BACK_PID" 2>/dev/null; then kill -KILL "$BACK_PID" 2>/dev/null || true; fi
  fi
  if [ -n "${FE_PID:-}" ]; then
    if kill -0 "$FE_PID" 2>/dev/null; then kill -KILL "$FE_PID" 2>/dev/null || true; fi
  fi
}
trap cleanup EXIT INT TERM
# poll backend health
HEALTH_OK=1
for i in $(seq 1 "$TIMEOUT_SECS"); do
  if curl -f -sS --max-time 3 http://127.0.0.1:5000/api/account/health >/dev/null 2>&1; then HEALTH_OK=0 && break; fi
  sleep 1
done
if [ $HEALTH_OK -ne 0 ]; then
  echo "backend health check failed" >&2
  echo "ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT:-}" >&2
  tail -n 200 "$LOGDIR/backend.log" || true
  exit 6
fi
# poll frontend
FE_OK=1
for i in $(seq 1 "$TIMEOUT_SECS"); do
  if curl -f -sS --max-time 3 http://127.0.0.1:4200/ >/dev/null 2>&1; then FE_OK=0 && break; fi
  sleep 1
done
if [ $FE_OK -ne 0 ]; then
  echo "frontend health check failed" >&2
  tail -n 200 "$LOGDIR/frontend.log" || true
  exit 7
fi
# success
echo "validation OK: backend and frontend responding"
exit 0
