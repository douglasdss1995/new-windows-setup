<#
.SYNOPSIS
    First-run setup: creates the local config files and asks which optional tools to install.
.DESCRIPTION
    Usually run through `make setup`. Copies the *.example configs that are missing
    (never overwrites), drops the keys of tools that became mandatory, then asks yes/no
    questions about every OPTIONAL Windows tool and WSL provider. Mandatory tools are never asked. Press Enter to accept the default
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

# Mandatory tools are always installed and no longer have a key: remove the ones
# an older config still carries so nobody believes they can switch them off.
$winConfigPath = Join-Path $RepoRoot 'windows' 'windows.config.psd1'
$retired = @(Remove-ConfigKeys -Path $winConfigPath -Keys (Get-WindowsRetiredKeys))
if ($retired.Count -gt 0) {
    Write-Host "[OK]   windows/windows.config.psd1: removed keys of tools that are now always installed (or dropped): $($retired -join ', ')" -ForegroundColor Green
    Write-Host '       (previous file kept as .bak)' -ForegroundColor DarkGray
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
# 2. Windows tools (optional ones only)
# -----------------------------------------------------------------------------
Write-Step 'Windows tools'
if (-not $UseDefaults) {
    Write-Host 'Mandatory tools are installed without asking. Answer y/yes/1 or n/no/0; Enter accepts the default (the capital letter).' -ForegroundColor DarkGray
}
$winCurrent = Import-PowerShellDataFile -Path $winConfigPath
$winAnswers = @{}
$lastSection = ''
foreach ($opt in Get-WindowsOptions) {
    $saved = $null
    if ($winCurrent.ContainsKey($opt.Section) -and $winCurrent[$opt.Section] -is [hashtable] -and $winCurrent[$opt.Section].ContainsKey($opt.Key)) {
        $saved = $winCurrent[$opt.Section][$opt.Key]
    }
    $default = if ($saved -is [bool]) { $saved } else { $opt.Default }
    if ($UseDefaults) { $winAnswers["$($opt.Section).$($opt.Key)"] = $default; continue }
    if ($opt.Section -ne $lastSection) {
        Write-Host "`n-- $($opt.Section) --" -ForegroundColor Cyan
        $lastSection = $opt.Section
    }
    if ($opt.Note) { Write-Host "  - $($opt.Note)" -ForegroundColor DarkGray }
    $winAnswers["$($opt.Section).$($opt.Key)"] = Read-YesNo -Prompt $opt.Question -Default $default
}
if ((Set-ConfigBooleans -Path $winConfigPath -Values $winAnswers) -gt 0) {
    Write-Host '[OK]   saved your choices in windows/windows.config.psd1' -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 3. WSL choices
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
# 4. Git identity (lives in windows.config.psd1, shared by Windows and WSL)
# -----------------------------------------------------------------------------
if (-not $UseDefaults) {
    Write-Step 'Git identity'
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
# 5. Next steps (installers need Administrator, so they are never launched here)
# -----------------------------------------------------------------------------
Write-Step 'Next steps (PowerShell as Administrator, from the repo root)'
Write-Host '  1. powershell -ExecutionPolicy Bypass -File setup-windows.ps1'
Write-Host '  2. pwsh -ExecutionPolicy Bypass -File setup-wsl.ps1'
Write-Host ''
Write-Host 'Run `make setup` again any time to change your optional choices.' -ForegroundColor DarkGray
