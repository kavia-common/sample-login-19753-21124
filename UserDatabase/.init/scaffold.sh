#!/usr/bin/env bash
set -euo pipefail
# scaffold minimal Angular frontend and ASP.NET WebAPI backend in authoritative workspace
WS="/home/kavia/workspace/code-generation/sample-login-19753-21124/UserDatabase"
mkdir -p "$WS/frontend/src/app" "$WS/backend/Controllers"
# frontend package.json: pin typescript locally to avoid global mismatch
cat > "$WS/frontend/package.json" <<'JSON'
{
  "name": "userdb-frontend",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "start": "ng serve --host 0.0.0.0 --disable-host-check --poll=2000",
    "build": "ng build --configuration development",
    "test": "echo 'no frontend tests' && exit 0"
  },
  "dependencies": {
    "@angular/core": "^16.0.0",
    "@angular/common": "^16.0.0",
    "@angular/platform-browser": "^16.0.0",
    "@angular/platform-browser-dynamic": "^16.0.0"
  },
  "devDependencies": {
    "@angular/cli": "^16.0.0",
    "@angular-devkit/build-angular": "^16.0.0",
    "tslib": "^2.5.0",
    "typescript": "~5.1.0"
  }
}
JSON
cat > "$WS/frontend/angular.json" <<'JSON'
{
  "$schema": "https://raw.githubusercontent.com/angular/angular-cli/v16.0.0/packages/angular/cli/schema.json",
  "version": 1,
  "defaultProject": "app",
  "projects": { "app": { "projectType": "application", "root": "src", "sourceRoot": "src", "architect": { "build": { "builder": "@angular-devkit/build-angular:browser", "options": { "outputPath": "dist", "index": "src/index.html", "main": "src/main.ts", "polyfills": "src/polyfills.ts", "tsConfig": "tsconfig.json" } }, "serve": { "builder": "@angular-devkit/build-angular:dev-server", "options": { "browserTarget": "app:build" } } } } }
}
JSON
cat > "$WS/frontend/tsconfig.json" <<'JSON'
{
  "compilerOptions": { "target": "es2017", "module": "es2020", "moduleResolution": "node", "experimentalDecorators": true, "emitDecoratorMetadata": true, "strict": true, "skipLibCheck": true, "types": [] },
  "angularCompilerOptions": { "enableIvy": true }
}
JSON
cat > "$WS/frontend/src/index.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>UserDatabase</title></head><body><app-root></app-root></body></html>
HTML
cat > "$WS/frontend/src/polyfills.ts" <<'TS'
// minimal polyfills for demo; add zone.js if change detection features are used
export {};
TS
cat > "$WS/frontend/src/app/app.component.ts" <<'TS'
import { Component } from '@angular/core';
@Component({ selector: 'app-root', template: '<h1>UserDatabase Frontend</h1>' })
export class AppComponent {}
TS
cat > "$WS/frontend/src/app/app.module.ts" <<'TS'
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { AppComponent } from './app.component';
@NgModule({ declarations: [AppComponent], imports: [BrowserModule], bootstrap: [AppComponent] })
export class AppModule {}
TS
cat > "$WS/frontend/src/main.ts" <<'TS'
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { AppModule } from './app/app.module';
platformBrowserDynamic().bootstrapModule(AppModule).catch(err => console.error(err));
TS
# backend
cat > "$WS/backend/UserDatabase.Api.csproj" <<'XML'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
XML
cat > "$WS/backend/Program.cs" <<'CS'
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Hosting;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
var app = builder.Build();
app.MapControllers();
app.Run();
CS
cat > "$WS/backend/Controllers/AccountController.cs" <<'CS'
using Microsoft.AspNetCore.Mvc;
[ApiController]
[Route("api/[controller]")]
public class AccountController : ControllerBase
{
    [HttpGet("health")]
    public IActionResult Health() => Ok(new { status = "ok" });
}
CS
cat > "$WS/backend/appsettings.Development.json" <<'JSON'
{
  "ConnectionStrings": { "DefaultConnection": "Data Source=dev.db" },
  "Jwt": { "Key": "dev-secret" }
}
JSON
# helper start scripts
cat > "$WS/start-frontend.sh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/frontend"
# install production+dev deps non-interactively; silence non-critical output
npm i --no-audit --no-fund --silent
exec npm run start
BASH
chmod +x "$WS/start-frontend.sh"
cat > "$WS/start-backend.sh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR/backend"
# force HTTP only to avoid HTTPS certificate interactions
ASPNETCORE_URLS=${ASPNETCORE_URLS:-"http://0.0.0.0:5000"}
export ASPNETCORE_URLS
# restore and run using dotnet CLI
dotnet restore --disable-parallel --verbosity minimal
exec dotnet run --urls "$ASPNETCORE_URLS"
BASH
chmod +x "$WS/start-backend.sh"

# create /etc/profile.d snippet idempotently to persist minimal env & PATH updates
PROFILE_FILE="/etc/profile.d/dev-env-userdb.sh"
sudo bash -c "cat > '$PROFILE_FILE' <<'SH'
# development environment for UserDatabase workspace
export NODE_ENV=development
export ASPNETCORE_ENVIRONMENT=Development
# compute DOTNET_ROOT at runtime
if [ -z "${DOTNET_ROOT-}" ]; then
  DOTNET_ROOT="$(command -v dotnet >/dev/null 2>&1 && dirname "$(dirname "$(command -v dotnet)")")"
  export DOTNET_ROOT
fi
# add npm global bin to PATH if not present
if command -v npm >/dev/null 2>&1; then
  NPM_GBIN="$(npm bin -g 2>/dev/null || true)"
  case ":$PATH:" in
    *":$NPM_GBIN:"*) ;;
    *) export PATH="$NPM_GBIN:$PATH";;
  esac
fi
SH"

# source into current shell to validate values (best effort)
# Do not fail if sudo/profile write not permitted; just warn
if [ -r "$PROFILE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$PROFILE_FILE" || true
fi
# quick validation output (concise)
command -v node >/dev/null && command -v npm >/dev/null || { echo "node/npm missing" >&2; exit 1; }
command -v dotnet >/dev/null || { echo "dotnet missing" >&2; exit 1; }

echo "scaffolded at $WS"
