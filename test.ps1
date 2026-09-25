<#
.SYNOPSIS
    Runs the test suites: Pester (PowerShell) and plain-bash tests for wsl/lib.
.EXAMPLE
    pwsh -File test.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$failed = $false

$pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester -or $pester.Version -lt [version]'5.0') {
    throw 'Pester 5+ required. Install: Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force -SkipPublisherCheck'
}
Import-Module Pester -MinimumVersion 5.0

Write-Host '== Pester ==' -ForegroundColor Cyan
$result = Invoke-Pester -Path (Join-Path $PSScriptRoot 'tests' 'pester') -Output Detailed -PassThru
if ($result.FailedCount -gt 0) { $failed = $true }

Write-Host '== bash ==' -ForegroundColor Cyan
if (Get-Command bash -ErrorAction SilentlyContinue) {
    foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot 'tests' 'bash') -Filter *.test.sh) {
        & bash ($file.FullName -replace '\\', '/')
        if ($LASTEXITCODE -ne 0) { $failed = $true }
    }
} else {
    Write-Warning 'bash not found - skipping bash tests'
}

if ($failed) { exit 1 }
