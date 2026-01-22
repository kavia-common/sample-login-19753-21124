#!/usr/bin/env bash
set -euo pipefail

# Idempotent dependency installer + compatibility checks
WS="/home/kavia/workspace/code-generation/sample-login-19753-21124/UserDatabase"
cd "$WS" || { echo "workspace missing: $WS" >&2; exit 2; }

# FRONTEND: ensure package.json exists and node_modules installed idempotently
FRONTEND="$WS/frontend"
mkdir -p "$FRONTEND"
cd "$FRONTEND"
if [ ! -f package.json ]; then
  cat > package.json <<'JSON'
{
  "name": "sample-frontend",
  "version": "0.0.0",
  "private": true,
  "scripts": { "build": "ng build", "start": "ng serve --host 0.0.0.0" },
  "dependencies": { "@angular/core": "^16.0.0" },
  "devDependencies": { "@angular/cli": "^16.0.0", "typescript": "4.9.5" }
}
JSON
fi
# install only if node_modules missing
if [ ! -d node_modules ]; then
  npm i --no-audit --no-fund --silent
fi

# Validate local ng CLI first (prefer local binary)
if [ -x "$FRONTEND/node_modules/.bin/ng" ]; then
  "$FRONTEND/node_modules/.bin/ng" --version >/dev/null 2>&1 || { echo "local ng invalid" >&2; exit 5; }
elif command -v ng >/dev/null 2>&1; then
  ng --version >/dev/null 2>&1 || { echo "global ng present but returned error" >&2; }
else
  echo "warning: ng not found" >&2
fi

# BACKEND: ensure csproj exists and Microsoft.Data.Sqlite referenced
BACKEND="$WS/backend"
mkdir -p "$BACKEND"
CDPROJ="$BACKEND/UserDatabase.Api.csproj"
if [ ! -f "$CDPROJ" ]; then
  mkdir -p "$BACKEND/Controllers"
  cat > "$CDPROJ" <<'XML'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
XML
  cat > "$BACKEND/Program.cs" <<'CS'
using Microsoft.AspNetCore.Builder;
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.MapGet("/health", () => Results.Ok("ok"));
app.Run();
CS
fi

# Add Microsoft.Data.Sqlite if missing
if ! dotnet list "$CDPROJ" package 2>/dev/null | grep -q "Microsoft.Data.Sqlite"; then
  for i in 1 2; do
    if dotnet add "$CDPROJ" package Microsoft.Data.Sqlite --version 8.1.5 --no-restore >/dev/null 2>&1; then break; fi
    sleep 1
  done
  dotnet list "$CDPROJ" package | grep -q "Microsoft.Data.Sqlite" || { echo "failed to add Microsoft.Data.Sqlite" >&2; exit 6; }
fi

# Restore packages with retry
for i in 1 2; do
  if dotnet restore --disable-parallel --verbosity minimal; then break; fi
  sleep 1
done

# Final validation: ensure dotnet and node accessible
command -v dotnet >/dev/null 2>&1 || { echo "dotnet not on PATH" >&2; exit 7; }
command -v npm >/dev/null 2>&1 || { echo "npm not on PATH" >&2; exit 8; }

echo "dependencies step completed"
