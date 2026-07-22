# =============================================================================
# setup-wsl.ps1 — WSL 2 + Ubuntu installation and configuration
# Run as Administrator in PowerShell
# Usage: .\setup-wsl.ps1 [-Distro ubuntu-24.04] [-SkipProvision]
# =============================================================================

param(
    # "ubuntu" tracks the latest Ubuntu LTS automatically (recommended).
    # Use "Ubuntu-24.04" to pin to a specific release.
    [string]$Distro        = "ubuntu",
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
try {
    wsl --update 2>&1 | Out-Null
    Write-OK "WSL kernel updated"
} catch {
    Write-Warn "WSL kernel update failed (no internet or Store blocked) — continuing with current version"
}

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
    Write-Host "  Create your user and password, then run this script again.`n" -ForegroundColor Cyan
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
    # Normalize to LF before writing into Linux — CRLF in /etc/wsl.conf causes
    # silent parse failures in systemd and automount.
    $wslConfContent = (Get-Content $wslConfSrc -Raw) -replace "`r`n", "`n" -replace "`r", "`n"

    # Step 1: write to a temp file in the user home via pipe (no sudo — stdin is
    #         occupied by the pipe so sudo would hang waiting for the password).
    $wslConfContent | wsl -d $Distro -- bash -c "cat > ~/wsl.conf.tmp"

    # Step 2: move to /etc/wsl.conf with sudo in a separate call that has a TTY,
    #         so the password prompt works if the user hasn't cached credentials.
    wsl -d $Distro -- sudo mv ~/wsl.conf.tmp /etc/wsl.conf

    Write-OK "wsl.conf configured at /etc/wsl.conf"
} else {
    Write-Warn "wsl.conf not found at $wslConfSrc — skipping"
}

# -----------------------------------------------------------------------------
# 7. Restart WSL to apply configuration
# -----------------------------------------------------------------------------
Write-Step "Restarting WSL to apply configuration"
wsl --shutdown
Start-Sleep -Seconds 5
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

    # Copy provision.sh to the Linux home directory and strip CRLF line endings.
    # Running directly from /mnt/c/... is slower (cross-OS filesystem) and breaks
    # if the file was saved with Windows CRLF endings (\r\n causes bash errors).
    $provisionContent = (Get-Content $provisionSrc -Raw) -replace "`r`n", "`n" -replace "`r", "`n"
    $provisionContent | wsl -d $Distro -- bash -c "cat > ~/provision.sh && chmod +x ~/provision.sh"

    # -------------------------------------------------------------------------
    # Resolve the repo root's WSL mount path, so provision.sh can symlink the
    # shared .gitconfig (repo root) straight into ~/.gitconfig instead of
    # keeping a separate copy of the same settings.
    # -------------------------------------------------------------------------
    $repoRoot    = Split-Path $PSScriptRoot -Parent
    $repoPathWsl = (wsl -d $Distro -- wslpath -a $repoRoot).Trim()

    # -------------------------------------------------------------------------
    # Git identity comes from windows.config.psd1 (single source of truth) so
    # it's applied automatically on the WSL side too, not just on Windows.
    # -------------------------------------------------------------------------
    $gitUserName  = ""
    $gitUserEmail = ""
    $winConfigPath = Join-Path $repoRoot "windows.config.psd1"
    if (Test-Path $winConfigPath) {
        $winCfg = Import-PowerShellDataFile -Path $winConfigPath
        if ($winCfg.Git) {
            $gitUserName  = $winCfg.Git.UserName
            $gitUserEmail = $winCfg.Git.UserEmail
        }
    } else {
        Write-Warn "windows.config.psd1 not found at $winConfigPath - Git identity won't be passed to WSL"
    }

    $provisionArgs = "--repo-path=`"$repoPathWsl`""
    if ($gitUserName)  { $provisionArgs += " --git-username=`"$gitUserName`"" }
    if ($gitUserEmail) { $provisionArgs += " --git-email=`"$gitUserEmail`"" }

    # Run from the Linux home directory
    wsl -d $Distro -- bash -c "bash ~/provision.sh $provisionArgs"

    Write-OK "provision.sh executed successfully"

    # -------------------------------------------------------------------------
    # First boot of providers — run after provision while Docker is already
    # active in the same WSL session, avoiding race conditions on next restart.
    # -------------------------------------------------------------------------
    Write-Step "Starting providers for the first time"
    Write-Host "  Waiting for Docker to be ready..." -ForegroundColor DarkGray
    $dockerReady = $false
    for ($i = 0; $i -lt 15; $i++) {
        $check = wsl -d $Distro -- bash -c "docker info > /dev/null 2>&1 && echo ok" 2>$null
        if ($check -match "ok") { $dockerReady = $true; break }
        Start-Sleep -Seconds 2
    }

    if ($dockerReady) {
        wsl -d $Distro -- bash -c "cd ~/providers && docker container prune -f > /dev/null 2>&1; docker compose up -d --remove-orphans" 2>&1
        Write-OK "Providers started"
    } else {
        Write-Warn "Docker did not become ready in time - run 'pvup' manually after opening WSL"
    }
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
