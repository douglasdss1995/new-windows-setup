# =============================================================================
# setup-wsl.ps1 — WSL 2 + Ubuntu installation and configuration
# Run as Administrator in PowerShell
# Usage: .\setup-wsl.ps1 [-Distro ubuntu-24.04] [-SkipProvision]
# =============================================================================

param(
    [string]$Distro        = "Ubuntu-24.04",
    [bool]  $SkipProvision = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Write-Step  { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[OK] $msg"   -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------------------
# Check Administrator
# -----------------------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Run this script as Administrator (right-click > Run as Administrator)"
}

# -----------------------------------------------------------------------------
# Marker file for resuming after restart
# -----------------------------------------------------------------------------
$markerFile = Join-Path $env:TEMP "wsl-setup-pending-restart.flag"

# -----------------------------------------------------------------------------
# 1. Enable required Windows features
# -----------------------------------------------------------------------------
Write-Step "Enabling Windows features"

$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform"
)

$restartNeeded = $false

foreach ($feature in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
    if ($state -ne "Enabled") {
        Write-Host "  Enabling $feature..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
        Write-OK "$feature enabled"
        $restartNeeded = $true
    } else {
        Write-OK "$feature already enabled"
    }
}

# A restart is required before continuing if any feature was just enabled
if ($restartNeeded) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  RESTART REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Windows features were enabled, but the system must" -ForegroundColor White
    Write-Host "  be restarted for WSL to work correctly." -ForegroundColor White
    Write-Host ""
    Write-Host "  After restarting, run this script again to continue" -ForegroundColor Cyan
    Write-Host "  the installation from where it left off." -ForegroundColor Cyan
    Write-Host ""

    # Create marker to signal setup was started
    "pending" | Out-File -FilePath $markerFile -Encoding UTF8
    Write-Host "  (Resume marker saved to: $markerFile)" -ForegroundColor DarkGray
    Write-Host ""

    $answer = Read-Host "  Restart now? (Y/N)"
    if ($answer -match '^[Yy]$') {
        Write-Host ""
        Write-Host "  Restarting in 5 seconds... Press Ctrl+C to cancel." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    } else {
        Write-Host ""
        Write-Warn "Restart the computer manually and run the script again."
        exit 0
    }
}

# Clear marker if it exists from a previous run
if (Test-Path $markerFile) {
    Remove-Item $markerFile -Force
    Write-Host "  (Resuming setup after restart)" -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 2. Update the WSL kernel
# -----------------------------------------------------------------------------
Write-Step "Updating WSL kernel"
wsl --update
Write-OK "WSL kernel updated"

# -----------------------------------------------------------------------------
# 3. Set WSL 2 as default
# -----------------------------------------------------------------------------
Write-Step "Setting WSL 2 as default"
wsl --set-default-version 2
Write-OK "WSL 2 set as default"

# -----------------------------------------------------------------------------
# 4. Install the distro
# -----------------------------------------------------------------------------
Write-Step "Checking distro: $Distro"

# wsl --list outputs UTF-16 with null bytes - strip them before matching
$installedDistros = (wsl --list --quiet 2>$null) -replace "`0", ""
$isInstalled = $installedDistros -match [regex]::Escape($Distro)

if (-not $isInstalled) {
    Write-Host "  Installing $Distro..." -ForegroundColor Yellow
    wsl --install -d $Distro --no-launch
    Write-OK "$Distro installed"
    Write-Warn "First run requires creating a user. Launch it manually once before continuing."
    Write-Host "`n  Run: wsl -d $Distro" -ForegroundColor Cyan
    Write-Host "  Create your user and password, then run this script again with -SkipProvision:`$false`n"
    exit 0
} else {
    Write-OK "$Distro already installed"
}

# -----------------------------------------------------------------------------
# 5. Copy .wslconfig to user profile
# -----------------------------------------------------------------------------
Write-Step "Installing .wslconfig"

$wslConfigSrc = Join-Path $PSScriptRoot ".wslconfig"
$wslConfigDst = Join-Path $env:USERPROFILE ".wslconfig"

if (Test-Path $wslConfigSrc) {
    Copy-Item -Path $wslConfigSrc -Destination $wslConfigDst -Force
    Write-OK ".wslconfig copied to $wslConfigDst"
} else {
    Write-Warn ".wslconfig not found at $wslConfigSrc — skipping"
}

# -----------------------------------------------------------------------------
# 6. Copy wsl.conf into the distro
# -----------------------------------------------------------------------------
Write-Step "Configuring wsl.conf in the distro"

$wslConfSrc = Join-Path $PSScriptRoot "wsl.conf"

if (Test-Path $wslConfSrc) {
    $wslConfContent = Get-Content $wslConfSrc -Raw
    # Write the file inside WSL via stdin
    $wslConfContent | wsl -d $Distro -- bash -c "sudo tee /etc/wsl.conf > /dev/null"
    Write-OK "wsl.conf configured at /etc/wsl.conf"
} else {
    Write-Warn "wsl.conf not found at $wslConfSrc — skipping"
}

# -----------------------------------------------------------------------------
# 7. Restart WSL to apply configuration
# -----------------------------------------------------------------------------
Write-Step "Restarting WSL to apply configuration"
wsl --shutdown
Start-Sleep -Seconds 2
Write-OK "WSL restarted"

# -----------------------------------------------------------------------------
# 8. Copy and run provision.sh inside WSL
# -----------------------------------------------------------------------------
if (-not $SkipProvision) {
    Write-Step "Running provision.sh in distro $Distro"

    $provisionSrc = Join-Path $PSScriptRoot "provision.sh"

    if (-not (Test-Path $provisionSrc)) {
        Write-Fail "provision.sh not found at $provisionSrc"
    }

    # Convert Windows path to WSL path
    $provisionWslPath = wsl -d $Distro -- wslpath -u "$provisionSrc"
    $provisionWslPath = $provisionWslPath.Trim()

    # Ensure execute permission and run
    wsl -d $Distro -- bash -c "chmod +x '$provisionWslPath' && bash '$provisionWslPath'"

    Write-OK "provision.sh executed successfully"
} else {
    Write-Warn "Provisioning skipped (-SkipProvision)"
}

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  WSL configured successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "To open WSL:"
Write-Host "  wsl -d $Distro" -ForegroundColor Cyan
Write-Host ""
Write-Host "To open in Windows Terminal:"
Write-Host "  Click the terminal arrow and select $Distro" -ForegroundColor Cyan
Write-Host ""
