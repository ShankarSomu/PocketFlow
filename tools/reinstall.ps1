#!/usr/bin/env pwsh
# reinstall.ps1 — Uninstall app, clear cache, build & reinstall fresh
# Usage: .\tools\reinstall.ps1 [-Device <deviceId>] [-Flavor <flavor>]

param(
  [string]$Device = "",
  [string]$Flavor = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pkg = "com.example.pocket_flow"  # change if your app id differs

function step($msg) { Write-Host "`n── $msg" -ForegroundColor Cyan }
function ok($msg)   { Write-Host "   ✓ $msg"   -ForegroundColor Green }
function warn($msg) { Write-Host "   ! $msg"   -ForegroundColor Yellow }

# ── 1. Resolve device ────────────────────────────────────────────────────────
step "Resolving device"
$adbArgs = @()
if ($Device) { $adbArgs = @("-s", $Device) }

$devices = (adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\bdevice\b" })
if (-not $devices) {
  Write-Host "No Android device/emulator connected." -ForegroundColor Red
  exit 1
}
if ($Device) { ok "Using device: $Device" } else { ok "Using first available device" }

# ── 2. Uninstall ─────────────────────────────────────────────────────────────
step "Uninstalling $pkg"
$uninstall = adb @adbArgs uninstall $pkg 2>&1
if ($uninstall -match "Success") {
  ok "Uninstalled"
} else {
  warn "App not installed (or already removed) — continuing"
}

# ── 3. Clear adb logcat buffer ───────────────────────────────────────────────
step "Clearing logcat buffer"
adb @adbArgs logcat -c
ok "Logcat cleared"

# ── 4. Flutter clean ─────────────────────────────────────────────────────────
step "flutter clean"
flutter clean
ok "Clean done"

# ── 5. Pub get ───────────────────────────────────────────────────────────────
step "flutter pub get"
flutter pub get
ok "Dependencies resolved"

# ── 6. Build & install ───────────────────────────────────────────────────────
$flutterArgs = @("run", "--debug")
if ($Device)  { $flutterArgs += @("-d", $Device) }
if ($Flavor)  { $flutterArgs += @("--flavor", $Flavor) }

step "flutter run (fresh install)"
Write-Host "   Running: flutter $($flutterArgs -join ' ')" -ForegroundColor Gray
flutter @flutterArgs
