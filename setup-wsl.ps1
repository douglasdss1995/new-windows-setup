# =============================================================================
# setup-wsl.ps1 — WSL 2 + Debian installation and configuration
# Run as Administrator in PowerShell 7.6+, from the repo root
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\setup-wsl.ps1 [-Distro Debian] [-SkipProvision]
#
# See docs/execution-policy.md if you hit a "running scripts is disabled" error.
# =============================================================================

param(
    # "Debian" tracks the current Debian release from the Microsoft Store
    # (Debian 13 "trixie" as of writing).
    [string]$Distro        = "Debian",
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

# Writes LF-normalized text content into a WSL distro without going through
# PowerShell's pipe-to-native-stdin redirection, which silently reintroduces a
# stray trailing `\r` (confirmed via `cat -A`) even when the source string only
# contains `\n`. Instead, the content is written to a Windows temp file and read
# back by bash's own `cat` via the file's /mnt/... path, so no PowerShell stdin
# encoding is involved.
function Copy-TextFileToWsl {
    param(
        [string]$Content,
        [string]$Distro,
        [string]$DestPath
    )
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.UTF8Encoding]::new($false))
        $wslTempPath = (wsl -d $Distro -e wslpath -a $tempFile).Trim()
        if (-not $wslTempPath) {
            Write-Fail "wslpath could not resolve temp file '$tempFile' inside $Distro"
        }
        wsl -d $Distro -- bash -c "cat '$wslTempPath' > $DestPath"
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Failed to write $DestPath inside $Distro"
        }
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

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

# WSL config templates, lib/*.sh, and setup-wsl.sh itself all live under wsl/.
$WslDir = Join-Path $PSScriptRoot "wsl"

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
    $installExitCode = $LASTEXITCODE

    # `wsl --install` can print a network error (e.g. 0x80072eff) yet still
    # exit 0, so don't trust the exit code alone - verify the distro actually
    # shows up in `wsl --list` before declaring success.
    $installedDistros = (wsl --list --quiet 2>$null) -replace "`0", ""
    $isInstalled = $installedDistros -match [regex]::Escape($Distro)

    if ($installExitCode -ne 0 -or -not $isInstalled) {
        Write-Fail "$Distro installation failed (exit code $installExitCode). This is usually a network issue - check your connection/VPN/firewall and rerun the script. You can also try 'wsl --install -d $Distro --no-launch' manually to see the raw error."
    }

    Write-OK "$Distro installed"

    # First boot needs an interactive TTY to create the Linux user/password,
    # which this script can't feed non-interactively. Open it in its own
    # console window and wait here instead of making the user rerun the script.
    Write-Warn "First run requires creating a user."
    Write-Host "  Opening $Distro in a new window - create your username and password there..." -ForegroundColor Cyan
    Start-Process wsl.exe -ArgumentList "-d", $Distro
    Read-Host "`n  Press Enter here once you've finished creating your user in the $Distro window"
} else {
    Write-OK "$Distro already installed"
}

# -----------------------------------------------------------------------------
# 5. Copy .wslconfig to user profile
# -----------------------------------------------------------------------------
Write-Step "Installing .wslconfig"

$wslConfigSrc = Join-Path $WslDir ".wslconfig"
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

$wslConfSrc = Join-Path $WslDir "wsl.conf"

if (Test-Path $wslConfSrc) {
    # Normalize to LF before writing into Linux — CRLF in /etc/wsl.conf causes
    # silent parse failures in systemd and automount.
    $wslConfContent = (Get-Content $wslConfSrc -Raw) -replace "`r`n", "`n" -replace "`r", "`n"

    # Step 1: write to a temp file in the user home (no sudo — that's step 2).
    Copy-TextFileToWsl -Content $wslConfContent -Distro $Distro -DestPath "~/wsl.conf.tmp"

    # Step 2: move to /etc/wsl.conf with sudo in a separate call that has a TTY,
    #         so the password prompt works if the user hasn't cached credentials.
    # Wrapped in `bash -c` (not passed raw to `wsl --`) so `~` is expanded by a
    # known bash process instead of whatever shell WSL picks for bare argv, which
    # can resolve it inconsistently.
    wsl -d $Distro -- bash -c "sudo mv ~/wsl.conf.tmp /etc/wsl.conf"

    Write-OK "wsl.conf configured at /etc/wsl.conf"
} else {
    Write-Warn "wsl.conf not found at $wslConfSrc — skipping"
}

# -----------------------------------------------------------------------------
# 7. Point Windows Terminal's WSL profiles at the Linux home directory
# -----------------------------------------------------------------------------
# Windows Terminal's auto-generated WSL profiles leave startingDirectory empty,
# which falls back to the Windows user profile folder (via /mnt/c) instead of
# the Linux home — makes every new WSL tab open in a slow, wrong location.
Write-Step "Configuring Windows Terminal startingDirectory for $Distro"

$wtSettingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtSettingsPath = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($wtSettingsPath) {
    try {
        $linuxUser = (wsl -d $Distro -- whoami).Trim()
        $homeDir = "//wsl`$/$Distro/home/$linuxUser"

        $wt = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        # Not every profile has a "source" property (built-in PowerShell/cmd
        # profiles don't) - guard the lookup so Set-StrictMode doesn't throw.
        $wslProfiles = $wt.profiles.list | Where-Object {
            ($_.PSObject.Properties.Name -contains 'source') -and
            ($_.source -eq "Microsoft.WSL") -and
            ($_.name -match [regex]::Escape($Distro))
        }

        if ($wslProfiles) {
            # Wrap wsl.exe in a PowerShell one-liner that stamps a start time and
            # forwards it via WSLENV, so .zshrc/.bashrc can report total launch
            # time (Windows command -> WSL prompt), not just shell-init time.
            $startupCmd = "powershell.exe -NoLogo -NoProfile -Command `"`$env:WSL_START_MS=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(); `$env:WSLENV='WSL_START_MS:'+`$env:WSLENV; wsl.exe -d $Distro`""
            foreach ($profile in $wslProfiles) {
                $profile | Add-Member -NotePropertyName startingDirectory -NotePropertyValue $homeDir -Force
                $profile | Add-Member -NotePropertyName commandline -NotePropertyValue $startupCmd -Force
            }
            $wt | ConvertTo-Json -Depth 20 | Set-Content $wtSettingsPath -Encoding UTF8
            Write-OK "Windows Terminal: $($wslProfiles.Count) profile(s) -> $homeDir (+ startup timer)"
        } else {
            Write-Warn "No Windows Terminal profile found for $Distro yet - open Windows Terminal once, then rerun"
        }
    } catch {
        Write-Warn "Could not update Windows Terminal settings.json: $_"
    }
} else {
    Write-Warn "Windows Terminal settings.json not found - skipping startingDirectory setup"
}

# -----------------------------------------------------------------------------
# 8. Restart WSL to apply configuration
# -----------------------------------------------------------------------------
Write-Step "Restarting WSL to apply configuration"
wsl --shutdown
Start-Sleep -Seconds 5
Write-OK "WSL restarted"

# -----------------------------------------------------------------------------
# 9. Copy and run setup-wsl.sh inside WSL
# -----------------------------------------------------------------------------
if (-not $SkipProvision) {
    Write-Step "Running setup-wsl.sh in distro $Distro"

    $provisionSrc = Join-Path $WslDir "setup-wsl.sh"
    $libSrcDir    = Join-Path $WslDir "lib"

    if (-not (Test-Path $provisionSrc)) {
        Write-Fail "setup-wsl.sh not found at $provisionSrc"
    }
    if (-not (Test-Path $libSrcDir)) {
        Write-Fail "wsl/lib not found at $libSrcDir"
    }

    # Transfer lib/*.sh first (same CRLF-stripping treatment as setup-wsl.sh),
    # preserving the same relative layout setup-wsl.sh expects: ~/wsl/lib/*.sh next to ~/wsl/setup-wsl.sh.
    wsl -d $Distro -- bash -c "mkdir -p ~/wsl/lib"
    Get-ChildItem -Path $libSrcDir -Filter "*.sh" | ForEach-Object {
        $libContent = (Get-Content $_.FullName -Raw) -replace "`r`n", "`n" -replace "`r", "`n"
        Copy-TextFileToWsl -Content $libContent -Distro $Distro -DestPath "~/wsl/lib/$($_.Name)"
    }
    Write-OK "provision lib files copied to ~/wsl/lib"

    # Copy setup-wsl.sh next to ~/wsl/lib and strip CRLF line endings.
    # Running directly from /mnt/c/... is slower (cross-OS filesystem) and breaks
    # if the file was saved with Windows CRLF endings (\r\n causes bash errors).
    $provisionContent = (Get-Content $provisionSrc -Raw) -replace "`r`n", "`n" -replace "`r", "`n"
    Copy-TextFileToWsl -Content $provisionContent -Distro $Distro -DestPath "~/wsl/setup-wsl.sh"
    wsl -d $Distro -- bash -c "chmod +x ~/wsl/setup-wsl.sh"

    # -------------------------------------------------------------------------
    # Resolve the repo root's WSL mount path, so setup-wsl.sh can symlink the
    # shared git/.gitconfig straight into ~/.gitconfig instead of keeping a
    # separate copy of the same settings.
    # -------------------------------------------------------------------------
    $repoRoot    = $PSScriptRoot
    # -e/--exec bypasses the distro's default shell (zsh here) so backslashes
    # in the Windows path aren't eaten as escape characters before wslpath sees them.
    $repoPathWsl = (wsl -d $Distro -e wslpath -a $repoRoot).Trim()
    if (-not $repoPathWsl) {
        Write-Fail "wslpath could not resolve '$repoRoot' inside $Distro"
    }

    # -------------------------------------------------------------------------
    # Git identity comes from windows/windows.config.psd1 (single source of
    # truth) so it's applied automatically on the WSL side too, not just on Windows.
    # -------------------------------------------------------------------------
    $gitUserName  = ""
    $gitUserEmail = ""
    $winConfigPath = Join-Path $repoRoot "windows\windows.config.psd1"
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
    wsl -d $Distro -- bash -c "bash ~/wsl/setup-wsl.sh $provisionArgs"
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "setup-wsl.sh failed inside $Distro (exit code $LASTEXITCODE) - see output above"
    }

    Write-OK "setup-wsl.sh executed successfully"

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
