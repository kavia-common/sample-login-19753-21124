#!/usr/bin/env bash
set -euo pipefail
# Minimal deterministic tests: frontend no-op, backend xUnit
WS="/home/kavia/workspace/code-generation/sample-login-19753-21124/UserDatabase"
# frontend: deterministic no-op test (intentional)
cd "$WS/frontend" || { echo "frontend folder missing: $WS/frontend" >&2; exit 2; }
# run npm test non-verbosely; allow package.json scripts to define test as no-op
npm run test --silent
# backend: ensure tests scaffold exists and run xUnit
cd "$WS/backend" || { echo "backend folder missing: $WS/backend" >&2; exit 3; }
mkdir -p tests
if [ ! -d "tests/UserDatabase.Tests" ]; then
  (cd tests && dotnet new xunit -n UserDatabase.Tests >/dev/null)
  (cd tests/UserDatabase.Tests && dotnet add reference ../../UserDatabase.Api.csproj >/dev/null || true)
fi
cd "$WS/backend/tests/UserDatabase.Tests" || { echo "tests project missing" >&2; exit 4; }
# run tests; fail the script if tests fail
dotnet test --verbosity minimal
