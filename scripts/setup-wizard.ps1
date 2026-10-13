<#
.SYNOPSIS
    First-run setup: creates the local config files and asks which WSL pieces to install.
.DESCRIPTION
    Usually run through `make setup`. Copies the *.example configs that are missing
    (never overwrites), then asks yes/no questions. Press Enter to accept the default
    shown in capitals; y/yes/1 mean yes and n/no/0 mean no. Re-running uses the values
    already saved as defaults.
.PARAMETER ConfigOnly
    Only copy the missing config files; ask nothing.
.PARAMETER UseDefaults
    Do not prompt: keep the saved values (or the defaults). For CI and scripting.
.PARAMETER RepoRoot
    Repo root to operate on. Defaults to the parent of this script's folder.
#>
[CmdletBinding()]
param(
    [switch]$ConfigOnly,
    [switch]$UseDefaults,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'SetupConfig.ps1')

function Write-Step { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# -----------------------------------------------------------------------------
# 1. Config files
# -----------------------------------------------------------------------------
Write-Step 'Config files'
foreach ($file in Copy-ConfigExamples -RepoRoot $RepoRoot) {
    if ($file.Created) {
        Write-Host "[OK]   created $($file.Path) from the example" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] $($file.Path) already exists" -ForegroundColor DarkGray
    }
}

# Keys added to the example after this machine's config was created (new tools,
# renamed flags) would otherwise be silently read as "disabled".
$syncPairs = @(
    @{ Config = 'windows/windows.config.psd1'; Example = 'windows/windows.config.psd1.example' }
)
foreach ($pair in $syncPairs) {
    $config = Join-Path $RepoRoot $pair.Config
    $sync = Sync-ConfigKeys -ExamplePath (Join-Path $RepoRoot $pair.Example) -ConfigPath $config
    if ($sync.Added.Count -gt 0) {
        Write-Host "[OK]   $($pair.Config): added new keys from the example: $($sync.Added -join ', ')" -ForegroundColor Green
        Write-Host '       (defaults from the example; previous file kept as .bak)' -ForegroundColor DarkGray
    }
    if ($sync.Unknown.Count -gt 0) {
        Write-Host "[WARN] $($pair.Config): keys not in the example (renamed or removed?): $($sync.Unknown -join ', ')" -ForegroundColor Yellow
    }
    if ($sync.Manual.Count -gt 0) {
        Write-Host "[WARN] $($pair.Config): add manually (multi-line or inline): $($sync.Manual -join ', ')" -ForegroundColor Yellow
    }
}
if ($ConfigOnly) { return }

# -----------------------------------------------------------------------------
# 2. WSL choices
# -----------------------------------------------------------------------------
$wslConfigPath = Join-Path $RepoRoot 'wsl' 'wsl.config.psd1'
$current = Import-PowerShellDataFile -Path $wslConfigPath

Write-Step 'WSL setup'
if (-not $UseDefaults) {
    Write-Host 'Answer y/yes/1 or n/no/0. Enter accepts the default (the capital letter).' -ForegroundColor DarkGray
}

$answers = @{}
foreach ($opt in Get-WslOptions) {
    $missing = @($opt.DependsOn | Where-Object { -not $answers[$_] })
    if ($missing.Count -gt 0) {
        $answers[$opt.Key] = $false
        Write-Host "  skipping '$($opt.Key)' (needs $($missing -join ', '))" -ForegroundColor DarkGray
        continue
    }
    $default = if ($current.ContainsKey($opt.Key) -and $current[$opt.Key] -is [bool]) { $current[$opt.Key] } else { $opt.Default }
    if (-not $UseDefaults) {
        Write-Host ''
        foreach ($h in Get-WslOptionHelp -Option $opt) { Write-Host "  - $h" -ForegroundColor DarkGray }
    }
    $answers[$opt.Key] = if ($UseDefaults) { $default } else { Read-YesNo -Prompt $opt.Question -Default $default }
}

Write-Utf8NoBom -Path $wslConfigPath -Content (New-WslConfigContent -Values $answers)
Write-Host '[OK]   saved wsl/wsl.config.psd1' -ForegroundColor Green

# -----------------------------------------------------------------------------
# 3. Git identity (lives in windows.config.psd1, shared by Windows and WSL)
# -----------------------------------------------------------------------------
if (-not $UseDefaults) {
    Write-Step 'Git identity'
    $winConfigPath = Join-Path $RepoRoot 'windows' 'windows.config.psd1'
    $winConfig = Import-PowerShellDataFile -Path $winConfigPath
    $git = if ($winConfig.ContainsKey('Git')) { $winConfig.Git } else { @{} }
    $curName  = if ($git.ContainsKey('UserName'))  { [string]$git.UserName }  else { '' }
    $curEmail = if ($git.ContainsKey('UserEmail')) { [string]$git.UserEmail } else { '' }

    $name  = Read-Text -Prompt 'Git user.name'  -Current $curName
    $email = Read-Text -Prompt 'Git user.email' -Current $curEmail
    if ($name -ne $curName -or $email -ne $curEmail) {
        Set-GitIdentityInConfig -Path $winConfigPath -UserName $name -UserEmail $email
        Write-Host '[OK]   saved Git identity in windows/windows.config.psd1' -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 4. Next steps (installers need Administrator, so they are never launched here)
# -----------------------------------------------------------------------------
Write-Step 'Next steps (PowerShell as Administrator, from the repo root)'
Write-Host '  1. powershell -ExecutionPolicy Bypass -File setup-windows.ps1'
Write-Host '  2. powershell -ExecutionPolicy Bypass -File setup-wsl.ps1'
Write-Host ''
Write-Host 'Review windows/windows.config.psd1 first if you want to change Windows tools.' -ForegroundColor DarkGray
