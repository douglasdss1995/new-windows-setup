<#
.SYNOPSIS
    Lints the repo: PSScriptAnalyzer for PowerShell, shellcheck for bash.
.EXAMPLE
    pwsh -File lint.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$failed = $false

if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    throw 'PSScriptAnalyzer missing. Install: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}

Write-Host '== PSScriptAnalyzer ==' -ForegroundColor Cyan
$issues = Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings (Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1')
if ($issues) {
    $issues | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize -Wrap | Out-String -Width 200 | Write-Host
    $failed = $true
} else {
    Write-Host 'OK' -ForegroundColor Green
}

Write-Host '== shellcheck ==' -ForegroundColor Cyan
if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
    $sh = Get-ChildItem (Join-Path $PSScriptRoot 'wsl'), (Join-Path $PSScriptRoot 'tests') -Recurse -Filter *.sh | ForEach-Object FullName
    & shellcheck -x -S warning @sh
    if ($LASTEXITCODE -ne 0) { $failed = $true } else { Write-Host 'OK' -ForegroundColor Green }
} else {
    Write-Warning 'shellcheck not found (scoop install shellcheck / apt install shellcheck) - skipping bash lint'
}

if ($failed) { exit 1 }
