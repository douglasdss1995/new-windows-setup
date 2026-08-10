# =============================================================================
# git-clone.ps1 - Clone git repositories from a config file
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\git-clone.ps1
#   powershell -ExecutionPolicy Bypass -File .\git-clone.ps1 -ConfigFile ".\my-other-config.psd1"
#   powershell -ExecutionPolicy Bypass -File .\git-clone.ps1 -DryRun        # preview without cloning
#
# See docs/execution-policy.md if you hit a "running scripts is disabled" error.
# =============================================================================
[CmdletBinding()]
param(
    [string] $ConfigFile = "$PSScriptRoot\git\git-repos.config.psd1",
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function Write-Header([string]$text) {
    Write-Host "`n=== $text ===" -ForegroundColor Cyan
}

function Write-Success([string]$text) {
    Write-Host "  [OK]  $text" -ForegroundColor Green
}

function Write-Skip([string]$text) {
    Write-Host "  [--]  $text" -ForegroundColor DarkGray
}

function Write-Fail([string]$text) {
    Write-Host "  [ERR] $text" -ForegroundColor Red
}

function Write-Info([string]$text) {
    Write-Host "        $text" -ForegroundColor Gray
}

# Build an HTTPS clone URL with an embedded token so git doesn't prompt.
# Result: https://oauth2:<token>@hostname/path.git
function Get-AuthenticatedUrl([string]$url, [string]$token) {
    $uri = [System.Uri]$url
    return "$($uri.Scheme)://oauth2:$token@$($uri.Host)$($uri.PathAndQuery)"
}

# Derive the destination folder name from the repository URL.
function Get-RepoName([string]$url) {
    $name = ($url.TrimEnd('/').Split('/')[-1])
    return $name -replace '\.git$', ''
}

# Find the provider whose Host matches the URL hostname.
function Resolve-Provider([hashtable]$providers, [string]$url, [string]$providerKey) {
    if (-not $providers.ContainsKey($providerKey)) {
        throw "Provider '$providerKey' not found in config. Available: $($providers.Keys -join ', ')"
    }
    return $providers[$providerKey]
}

# Configure a temporary SSH command for this clone if using SSH key auth.
function Get-SshEnv([string]$sshKey) {
    if (-not (Test-Path $sshKey)) {
        throw "SSH key not found: $sshKey"
    }
    # Normalise path for GIT_SSH_COMMAND (needs forward slashes)
    $normalised = $sshKey.Replace('\', '/')
    return "ssh -i `"$normalised`" -o StrictHostKeyChecking=accept-new"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

Write-Header "Git Repository Cloner"

# Load config
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    exit 1
}
$cfg = Import-PowerShellDataFile -Path $ConfigFile

$baseDir  = $cfg.CloneBaseDir
$repos    = $cfg.Repositories
$providers = $cfg.Providers

if ($repos.Count -eq 0) {
    Write-Host "`nNo repositories configured in '$ConfigFile'." -ForegroundColor Yellow
    exit 0
}

Write-Info "Config : $ConfigFile"
Write-Info "BaseDir: $baseDir"
Write-Info "Repos  : $($repos.Count)"
if ($DryRun) { Write-Host "`n  *** DRY RUN - nothing will be cloned ***" -ForegroundColor Yellow }

# Ensure base directory exists
if (-not $DryRun -and -not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
    Write-Info "Created base directory: $baseDir"
}

$results = @{ Success = 0; Skipped = 0; Failed = 0 }

foreach ($repo in $repos) {
    $url         = $repo.Url
    $providerKey = $repo.Provider
    $destName    = if ($repo.ContainsKey('Dir') -and $repo.Dir) { $repo.Dir } else { Get-RepoName $url }
    $branch      = if ($repo.ContainsKey('Branch') -and $repo.Branch) { $repo.Branch } else { $null }
    $destPath    = Join-Path $baseDir $destName

    Write-Host ""
    Write-Host "  $destName" -ForegroundColor White
    Write-Info "Url: $url"

    # Check if already cloned
    if (Test-Path (Join-Path $destPath '.git')) {
        Write-Skip "Already cloned at '$destPath'"
        $results.Skipped++
        continue
    }

    try {
        $provider = Resolve-Provider $providers $url $providerKey
        $isSSH    = $url.StartsWith("git@") -or $url.StartsWith("ssh://")

        if ($DryRun) {
            $authMethod = if ($isSSH) { "SSH ($($provider.SSHKey))" } else { "Token (HTTPS)" }
            Write-Info "Would clone -> $destPath  [$authMethod]"
            if ($branch) { Write-Info "Branch: $branch" }
            $results.Success++
            continue
        }

        # Build clone arguments
        $gitArgs = @("clone")

        if ($branch) {
            $gitArgs += "--branch", $branch
        }

        if ($isSSH) {
            # SSH authentication via custom key
            if (-not $provider.ContainsKey('SSHKey') -or -not $provider.SSHKey) {
                throw "Provider '$providerKey' has no SSHKey configured but URL is SSH."
            }
            $sshCmd = Get-SshEnv $provider.SSHKey
            $env:GIT_SSH_COMMAND = $sshCmd
            $gitArgs += $url, $destPath
            git @gitArgs
            Remove-Item Env:\GIT_SSH_COMMAND -ErrorAction SilentlyContinue
        }
        else {
            # HTTPS authentication via token
            if (-not $provider.ContainsKey('Token') -or -not $provider.Token) {
                throw "Provider '$providerKey' has no Token configured."
            }
            $authUrl  = Get-AuthenticatedUrl $url $provider.Token
            $gitArgs += $authUrl, $destPath
            git @gitArgs

            # Remove the embedded credentials from the remote so they're not
            # stored in .git/config in plain text.
            git -C $destPath remote set-url origin $url
        }

        if ($LASTEXITCODE -ne 0) { throw "git clone exited with code $LASTEXITCODE" }

        Write-Success "Cloned to '$destPath'"
        $results.Success++
    }
    catch {
        Write-Fail "$_"
        $results.Failed++
    }
}

# Summary
Write-Header "Summary"
Write-Host "  Cloned : $($results.Success)" -ForegroundColor Green
Write-Host "  Skipped: $($results.Skipped)" -ForegroundColor DarkGray
Write-Host "  Failed : $($results.Failed)" -ForegroundColor $(if ($results.Failed -gt 0) { 'Red' } else { 'DarkGray' })
Write-Host ""
