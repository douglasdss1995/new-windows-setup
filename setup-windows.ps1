# =============================================================================
# setup-windows.ps1 - Complete setup for a freshly formatted Windows machine
# Based on ferramentas.md - Dev Django + Angular
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
#
# See docs/execution-policy.md if you hit a "running scripts is disabled" error.
#
# Edit windows\windows.config.psd1 to enable/disable tools and configure Git.
# Requires running as Administrator.
# Compatible with PowerShell 5.1+
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Write-Step { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg"  -ForegroundColor Green }
function Write-Skip { param($msg) Write-Host "  [--] $msg"  -ForegroundColor DarkGray }
function Write-Warn { param($msg) Write-Host "  [!!] $msg"  -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  [XX] $msg"  -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  [>>] $msg"  -ForegroundColor DarkCyan }

$script:Installed = 0
$script:Skipped   = 0
$script:Failed    = 0
$script:FailList  = @()

# PowerShell 7's "all hosts" profile, hardcoded rather than read from $PROFILE.
# setup-windows.ps1 is commonly launched from elevated Windows PowerShell 5.1, whose
# $PROFILE.CurrentUserAllHosts points at Documents\WindowsPowerShell\profile.ps1
# instead of pwsh's Documents\PowerShell\profile.ps1 - activation lines written
# there would silently never load in the PS7 shell you actually use day to day.
$script:Ps7ProfilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\profile.ps1"

# This script lives at the repo root; windows.config.psd1 and themes/ live
# under windows/.
$RepoRoot  = $PSScriptRoot
$WindowsDir = Join-Path $RepoRoot "windows"

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
$ConfigFile = Join-Path $WindowsDir "windows.config.psd1"

if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Configuration file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "        Create the windows.config.psd1 file in the windows\ folder." -ForegroundColor Yellow
    exit 1
}

$cfg = Import-PowerShellDataFile -Path $ConfigFile
Write-Host ""
Write-Host "  Configuration loaded: $ConfigFile" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# Check Execution Policy
# -----------------------------------------------------------------------------
$pol = Get-ExecutionPolicy -Scope CurrentUser
if ($pol -eq "Restricted" -or $pol -eq "AllSigned") {
    Write-Warn "Execution Policy blocked ($pol) - adjusting to RemoteSigned..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-OK "Execution Policy updated"
}

# -----------------------------------------------------------------------------
# Check Administrator
# -----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[ERROR] Run as Administrator." -ForegroundColor Red
    Write-Host "        Right-click PowerShell > 'Run as administrator'" -ForegroundColor Red
    Write-Host "        Then run: powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# -----------------------------------------------------------------------------
# Function: install via winget
# -----------------------------------------------------------------------------
function Install-Pkg {
    param(
        [string]$Name,
        [string]$Id,
        [string]$Extra
    )

    $check = winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
    if ($check -match [regex]::Escape($Id)) {
        Write-Skip "$Name (already installed)"
        $script:Skipped++
        return
    }

    Write-Host "  --> $Name..." -ForegroundColor White
    if ($Extra) {
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements $Extra
    } else {
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    }

    if ($LASTEXITCODE -eq 0) {
        Write-OK $Name
        $script:Installed++
    } else {
        Write-Fail "$Name (exit code $LASTEXITCODE)"
        $script:FailList += $Name
        $script:Failed++
    }
}

# -----------------------------------------------------------------------------
# Function: install via Chocolatey
# -----------------------------------------------------------------------------
function Install-Choco {
    param([string]$Name, [string]$Pkg)

    $list = choco list --local-only $Pkg 2>&1 | Out-String
    if ($list -match $Pkg) {
        Write-Skip "$Name (already installed)"
        $script:Skipped++
        return
    }

    Write-Host "  --> $Name (choco)..." -ForegroundColor White
    choco install $Pkg -y --no-progress 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-OK $Name
        $script:Installed++
    } else {
        Write-Fail $Name
        $script:FailList += $Name
        $script:Failed++
    }
}

# -----------------------------------------------------------------------------
# Function: install JetBrains IDE via Toolbox (with winget fallback)
#
# The Toolbox App exposes a local REST API after startup. We discover the port
# from the lock file it creates, POST an install request, and fall back to a
# direct winget install if the API is unavailable or returns an error.
# Downloads always originate from download.jetbrains.com regardless of method.
# -----------------------------------------------------------------------------
function Install-JetBrainsTool {
    param(
        [string]$Name,
        [string]$WingetId,
        [string]$ToolboxTag   # product tag used by Toolbox API, e.g. "WebStorm"
    )

    # Skip if already installed (winget check covers both Toolbox and direct installs)
    $check = winget list --id $WingetId --exact --accept-source-agreements 2>&1 | Out-String
    if ($check -match [regex]::Escape($WingetId)) {
        Write-Skip "$Name (already installed)"
        $script:Skipped++
        return
    }

    $toolboxExe = "$env:LOCALAPPDATA\JetBrains\Toolbox\bin\jetbrains-toolbox.exe"

    if ((Test-Path $toolboxExe) -and $ToolboxTag) {
        Write-Host "  --> $Name (via JetBrains Toolbox)..." -ForegroundColor White

        # Start Toolbox minimized if not already running
        $tbProc = Get-Process -Name "jetbrains-toolbox" -ErrorAction SilentlyContinue
        if (-not $tbProc) {
            Start-Process $toolboxExe -ArgumentList "--minimized" -WindowStyle Hidden
            Write-Info "Waiting for Toolbox to initialize..."
            Start-Sleep -Seconds 8
        }

        # Toolbox writes its REST API port to a JSON lock file
        $portFile = "$env:LOCALAPPDATA\JetBrains\Toolbox\.lock"
        $apiPort  = $null

        if (Test-Path $portFile) {
            try {
                $lockData = Get-Content $portFile -Raw -ErrorAction Stop | ConvertFrom-Json
                $apiPort  = $lockData.port
            } catch { }
        }

        # Fallback: scan common Toolbox port range (63342-63352)
        if (-not $apiPort) {
            foreach ($p in 63342..63352) {
                try {
                    $r = Invoke-RestMethod "http://localhost:$p/api/about" -TimeoutSec 1 -ErrorAction Stop
                    if ($r) { $apiPort = $p; break }
                } catch { }
            }
        }

        if ($apiPort) {
            try {
                Invoke-RestMethod -Uri "http://localhost:$apiPort/api/tools/$ToolboxTag/install" `
                                  -Method Post -TimeoutSec 30 -ErrorAction Stop | Out-Null
                Write-OK "$Name (Toolbox)"
                $script:Installed++
                return
            } catch {
                Write-Warn "$Name - Toolbox API unavailable, falling back to winget..."
            }
        } else {
            Write-Warn "$Name - could not reach Toolbox API, falling back to winget..."
        }
    }

    # Fallback: direct winget install (downloads from official JetBrains CDN)
    Write-Host "  --> $Name (winget)..." -ForegroundColor White
    winget install --id $WingetId --exact --silent --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Name"
        $script:Installed++
    } else {
        Write-Fail "$Name (exit code $LASTEXITCODE)"
        $script:FailList += $Name
        $script:Failed++
    }
}

# -----------------------------------------------------------------------------
# Function: install VS Code extension
# -----------------------------------------------------------------------------
function Install-VSExt {
    param([string]$Id)

    $list = code --list-extensions 2>&1 | Out-String
    if ($list -match [regex]::Escape($Id)) {
        Write-Skip $Id
        $script:Skipped++
        return
    }

    code --install-extension $Id --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK $Id
        $script:Installed++
    } else {
        Write-Fail $Id
        $script:FailList += $Id
        $script:Failed++
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Setup - Dev Django + Angular" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# =============================================================================
# 1. PACKAGE MANAGERS
# =============================================================================
Write-Step "Package Managers"

Write-Info "Updating winget sources..."
winget source update 2>&1 | Out-Null

if ($cfg.PackageManagers.Chocolatey) {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Skip "Chocolatey (already installed)"
        $script:Skipped++
    } else {
        Write-Host "  --> Chocolatey..." -ForegroundColor White
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-OK "Chocolatey"
            $script:Installed++
        } else {
            Write-Fail "Chocolatey"
            $script:FailList += "Chocolatey"
            $script:Failed++
        }
    }
} else {
    Write-Skip "Chocolatey (disabled in config)"
    $script:Skipped++
}

# =============================================================================
# 2. TERMINAL AND SHELL
# =============================================================================
Write-Step "Terminal and Shell"

if ($cfg.Terminal.WindowsTerminal) { Install-Pkg "Windows Terminal"  "Microsoft.WindowsTerminal" } else { Write-Skip "Windows Terminal (disabled)" }
if ($cfg.Terminal.PowerShell7)     { Install-Pkg "PowerShell 7"      "Microsoft.PowerShell"      } else { Write-Skip "PowerShell 7 (disabled)"  }
if ($cfg.Terminal.Git)             { Install-Pkg "Git + Git Bash"    "Git.Git"                   } else { Write-Skip "Git (disabled)"           }
if ($cfg.Terminal.OhMyPosh)        { Install-Pkg "Oh My Posh"        "JanDeDobbeleer.OhMyPosh"   } else { Write-Skip "Oh My Posh (disabled)"   }
if ($cfg.Terminal.Starship)        { Install-Pkg "Starship"          "Starship.Starship"          } else { Write-Skip "Starship (disabled)"     }
if ($cfg.Terminal.Zoxide)          { Install-Pkg "zoxide"            "ajeetdsouza.zoxide"         } else { Write-Skip "zoxide (disabled)"       }
if ($cfg.Terminal.Fzf)             { Install-Pkg "fzf"               "junegunn.fzf"               } else { Write-Skip "fzf (disabled)"         }

if ($cfg.Terminal.OhMyPosh) {
    # Activate Oh My Posh in the PowerShell profile, pointing at the theme file
    # kept in windows/themes/ so it can be customized without touching this script.
    $themeFile = Join-Path $WindowsDir "themes\$($cfg.Terminal.OhMyPoshTheme)"

    if (Test-Path $themeFile) {
        $ompLine     = "oh-my-posh init pwsh --config '$themeFile' | Invoke-Expression"
        $profilePath = $script:Ps7ProfilePath

        if (-not (Test-Path $profilePath)) {
            New-Item -ItemType File -Path $profilePath -Force | Out-Null
        }

        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch [regex]::Escape($ompLine)) {
            Add-Content -Path $profilePath -Value "`n# Oh My Posh - prompt theme activation`n$ompLine"
            Write-OK "Oh My Posh activation added to PowerShell profile ($profilePath)"
        } else {
            Write-Skip "Oh My Posh activation already in PowerShell profile"
        }
    } else {
        Write-Warn "Oh My Posh theme not found at $themeFile - skipping profile activation"
    }
}

# =============================================================================
# 3. EDITORS AND IDEs
# =============================================================================
Write-Step "Editors and IDEs"

if ($cfg.Editors.VSCode)  { Install-Pkg "VS Code" "Microsoft.VisualStudioCode" } else { Write-Skip "VS Code (disabled)"  }
if ($cfg.Editors.Cursor)  { Install-Pkg "Cursor"  "Anysphere.Cursor"           } else { Write-Skip "Cursor (disabled)"  }

# JetBrains Toolbox - install first so the IDEs below can use it
if ($cfg.Editors.JetBrainsToolbox) {
    Install-Pkg "JetBrains Toolbox" "JetBrains.Toolbox"
    Write-Info "Toolbox installed - subsequent JetBrains IDEs will install via Toolbox API when available."
} else {
    Write-Skip "JetBrains Toolbox (disabled)"
}

# JetBrains IDEs - use Toolbox when available, direct winget as fallback
# All packages download from download.jetbrains.com regardless of method.
if ($cfg.Editors.PyCharm)             { Install-JetBrainsTool "PyCharm Community"    "JetBrains.PyCharm.Community"    "PyCharm"    } else { Write-Skip "PyCharm Community (disabled)"    }
if ($cfg.Editors.PyCharmProfessional) { Install-JetBrainsTool "PyCharm Professional" "JetBrains.PyCharm.Professional" "PyCharm"    } else { Write-Skip "PyCharm Professional (disabled)" }
if ($cfg.Editors.WebStorm)            { Install-JetBrainsTool "WebStorm"             "JetBrains.WebStorm"             "WebStorm"   } else { Write-Skip "WebStorm (disabled)"             }
if ($cfg.Editors.DataGrip)            { Install-JetBrainsTool "DataGrip"             "JetBrains.DataGrip"             "DataGrip"   } else { Write-Skip "DataGrip (disabled)"             }

# =============================================================================
# 4. GIT AND VERSION CONTROL
# =============================================================================
Write-Step "Git and Version Control"

if ($cfg.GitTools.GitHubCLI)  { Install-Pkg "GitHub CLI"  "GitHub.cli"          } else { Write-Skip "GitHub CLI (disabled)"  }
if ($cfg.GitTools.GitKraken)  { Install-Pkg "GitKraken"   "Axosoft.GitKraken"   } else { Write-Skip "GitKraken (disabled)"  }
if ($cfg.GitTools.Delta)      { Install-Pkg "delta"        "dandavison.delta"    } else { Write-Skip "delta (disabled)"      }

# =============================================================================
# 5. RUNTIMES AND VERSION MANAGERS
# =============================================================================
Write-Step "Runtimes and Version Managers"

if ($cfg.Runtimes.Mise) {
    Install-Pkg "mise" "jdx.mise"

    # Configure mise activation in the PowerShell profile so `mise use` works
    # per-directory inside PowerShell sessions.
    $miseLine = 'mise activate pwsh | Out-String | Invoke-Expression'
    $profilePath = $script:Ps7ProfilePath

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($profileContent -notmatch [regex]::Escape($miseLine)) {
        Add-Content -Path $profilePath -Value "`n# mise - version manager activation`n$miseLine"
        Write-OK "mise activation added to PowerShell profile ($profilePath)"
    } else {
        Write-Skip "mise activation already in PowerShell profile"
    }

    # Also add the shims directory to the Windows user PATH so mise-managed
    # tools resolve outside PowerShell too (VS Code integrated terminal,
    # cmd.exe, GUI apps launched via PATH, etc.) without relying on activation.
    $miseShims = "$env:LOCALAPPDATA\mise\shims"
    $userPath  = [Environment]::GetEnvironmentVariable("PATH", "User")

    if ($userPath -notmatch [regex]::Escape($miseShims)) {
        $userPath = "$miseShims;$userPath"
        [Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
        Write-OK "mise shims added to PATH (restart terminal to apply)"
    } else {
        Write-Skip "mise shims already in PATH"
    }
} else {
    Write-Skip "mise (disabled)"
}

if ($cfg.Runtimes.PyenvWin) {
    Install-Pkg "pyenv-win" "pyenv-win.pyenv-win"

    # pyenv-win requires its bin and shims directories in PATH to work after install
    $pyenvBin   = "$env:USERPROFILE\.pyenv\pyenv-win\bin"
    $pyenvShims = "$env:USERPROFILE\.pyenv\pyenv-win\shims"
    $userPath   = [Environment]::GetEnvironmentVariable("PATH", "User")

    $pathChanged = $false
    foreach ($entry in @($pyenvBin, $pyenvShims)) {
        if ($userPath -notmatch [regex]::Escape($entry)) {
            $userPath    = "$entry;$userPath"
            $pathChanged = $true
        }
    }

    if ($pathChanged) {
        [Environment]::SetEnvironmentVariable("PATH", $userPath, "User")
        Write-OK "pyenv-win added to PATH (restart terminal to apply)"
    } else {
        Write-Skip "pyenv-win already in PATH"
    }
} else { Write-Skip "pyenv-win (disabled)" }
if ($cfg.Runtimes.NvmWindows) { Install-Pkg "nvm-windows"            "CoreyButler.NVMforWindows"        } else { Write-Skip "nvm-windows (disabled)" }
if ($cfg.Runtimes.Python313)  { Install-Pkg "Python 3.13"            "Python.Python.3.13"               } else { Write-Skip "Python 3.13 (disabled)" }
if ($cfg.Runtimes.NodeLTS)    { Install-Pkg "Node.js LTS"            "OpenJS.NodeJS.LTS"                } else { Write-Skip "Node.js LTS (disabled)" }
if ($cfg.Runtimes.Java21)     { Install-Pkg "Eclipse Temurin 21 JDK" "EclipseAdoptium.Temurin.21.JDK"  } else { Write-Skip "Java 21 (disabled)"     }

if ($cfg.Runtimes.Uv) {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Skip "uv (already installed)"
        $script:Skipped++
    } else {
        Write-Host "  --> uv..." -ForegroundColor White
        powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
        if (Get-Command uv -ErrorAction SilentlyContinue) {
            Write-OK "uv"
            $script:Installed++
        } else {
            Write-Warn "uv - restart terminal and verify installation"
        }
    }
} else {
    Write-Skip "uv (disabled)"
}

if ($cfg.Runtimes.Pnpm) {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Skip "pnpm (already installed)"
        $script:Skipped++
    } else {
        Write-Host "  --> pnpm..." -ForegroundColor White
        Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            Write-OK "pnpm"
            $script:Installed++
        } else {
            Write-Warn "pnpm - restart terminal and verify installation"
        }
    }
} else {
    Write-Skip "pnpm (disabled)"
}

# =============================================================================
# 6. DATABASES
# =============================================================================
Write-Step "Databases"

if ($cfg.Database.PostgreSQL18)  { Install-Pkg "PostgreSQL 18"     "PostgreSQL.PostgreSQL.18"          } else { Write-Skip "PostgreSQL 18 (disabled)"   }
if ($cfg.Database.DBeaver)       { Install-Pkg "DBeaver"           "dbeaver.dbeaver"                   } else { Write-Skip "DBeaver (disabled)"          }
if ($cfg.Database.TablePlus)     { Install-Pkg "TablePlus"         "TablePlus.TablePlus"               } else { Write-Skip "TablePlus (disabled)"        }
if ($cfg.Database.PgAdmin)       { Install-Pkg "pgAdmin 4"         "PostgreSQL.pgAdmin"                } else { Write-Skip "pgAdmin (disabled)"          }
if ($cfg.Database.RedisInsight)  { Install-Pkg "Redis Insight"     "RedisLabs.RedisInsight"            } else { Write-Skip "Redis Insight (disabled)"    }
if ($cfg.Database.SQLiteBrowser) { Install-Pkg "DB Browser SQLite" "DBBrowserForSQLite.DBBrowserForSQLite" } else { Write-Skip "SQLite Browser (disabled)" }

# =============================================================================
# 7. DOCKER AND INFRASTRUCTURE
# =============================================================================
Write-Step "Docker and Infrastructure"

Write-Info "Docker runs via native Docker Engine in WSL - no Docker Desktop needed."
Write-Info "Run setup-wsl.ps1 to install and configure it."
Write-Info "Benefit: ~50-150 MB RAM vs ~1 GB for Docker Desktop."

# =============================================================================
# 8. API AND HTTP TESTING
# =============================================================================
Write-Step "API and HTTP Testing"

if ($cfg.API.Postman)  { Install-Pkg "Postman"  "Postman.Postman"  } else { Write-Skip "Postman (disabled)"  }
if ($cfg.API.Insomnia) { Install-Pkg "Insomnia" "Kong.Insomnia"    } else { Write-Skip "Insomnia (disabled)" }
if ($cfg.API.Bruno)    { Install-Pkg "Bruno"    "Bruno.Bruno"      } else { Write-Skip "Bruno (disabled)"    }

# =============================================================================
# 9. CLI UTILITIES
# =============================================================================
Write-Step "CLI Utilities"

if ($cfg.CLI.Ripgrep) { Install-Pkg "ripgrep" "BurntSushi.ripgrep.MSVC" } else { Write-Skip "ripgrep (disabled)" }
if ($cfg.CLI.Fd)      { Install-Pkg "fd"      "sharkdp.fd"              } else { Write-Skip "fd (disabled)"      }
if ($cfg.CLI.Bat)     { Install-Pkg "bat"     "sharkdp.bat"             } else { Write-Skip "bat (disabled)"     }
if ($cfg.CLI.Eza)     { Install-Pkg "eza"     "eza-community.eza"       } else { Write-Skip "eza (disabled)"     }
if ($cfg.CLI.Delta)   { Install-Pkg "delta"   "dandavison.delta"        } else { Write-Skip "delta (disabled)"   }
if ($cfg.CLI.Jq)      { Install-Pkg "jq"      "jqlang.jq"               } else { Write-Skip "jq (disabled)"      }
if ($cfg.CLI.Yq)      { Install-Pkg "yq"      "MikeFarah.yq"            } else { Write-Skip "yq (disabled)"      }
if ($cfg.CLI.Wget)    { Install-Pkg "wget"    "JernejSimoncic.Wget"     } else { Write-Skip "wget (disabled)"    }
if ($cfg.CLI.Make)    { Install-Choco "make"   "make"                    } else { Write-Skip "make (disabled)"    }
if ($cfg.CLI.Sudo)    { Install-Choco "sudo"   "gsudo"                   } else { Write-Skip "sudo (disabled)"    }
if ($cfg.CLI.Just)    { Install-Pkg "just"    "Casey.Just"              } else { Write-Skip "just (disabled)"    }
if ($cfg.CLI.Curl)    { Install-Pkg "curl"    "cURL.cURL"               } else { Write-Skip "curl (disabled)"    }

# =============================================================================
# 10. SECURITY AND AUTHENTICATION
# =============================================================================
Write-Step "Security and Authentication"

if ($cfg.Security.Bitwarden) { Install-Pkg "Bitwarden" "Bitwarden.Bitwarden" } else { Write-Skip "Bitwarden (disabled)" }
if ($cfg.Security.Gpg4win)   { Install-Pkg "Gpg4win"   "GnuPG.Gpg4win"      } else { Write-Skip "Gpg4win (disabled)"   }

if ($cfg.Security.OpenSSH) {
    $ssh = Get-WindowsCapability -Online -Name "OpenSSH.Client*"
    if ($ssh.State -eq "Installed") {
        Write-Skip "OpenSSH Client (already installed)"
        $script:Skipped++
    } else {
        Write-Host "  --> OpenSSH Client..." -ForegroundColor White
        Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" | Out-Null
        Write-OK "OpenSSH Client"
        $script:Installed++
    }
} else {
    Write-Skip "OpenSSH (disabled)"
}

# =============================================================================
# 11. PRODUCTIVITY
# =============================================================================
Write-Step "Productivity and Organization"

if ($cfg.Productivity.Obsidian)   { Install-Pkg "Obsidian"      "Obsidian.Obsidian"           } else { Write-Skip "Obsidian (disabled)"    }
if ($cfg.Productivity.Notion)     { Install-Pkg "Notion"        "Notion.Notion"               } else { Write-Skip "Notion (disabled)"      }
if ($cfg.Productivity.Slack)      { Install-Pkg "Slack"         "SlackTechnologies.Slack"     } else { Write-Skip "Slack (disabled)"       }
if ($cfg.Productivity.Discord)    { Install-Pkg "Discord"       "Discord.Discord"             } else { Write-Skip "Discord (disabled)"     }
if ($cfg.Productivity.ShareX)     { Install-Pkg "ShareX"        "ShareX.ShareX"              } else { Write-Skip "ShareX (disabled)"      }
if ($cfg.Productivity.PowerToys)  { Install-Pkg "PowerToys"     "Microsoft.PowerToys"        } else { Write-Skip "PowerToys (disabled)"   }
if ($cfg.Productivity.Everything) { Install-Pkg "Everything"    "voidtools.Everything"       } else { Write-Skip "Everything (disabled)"  }
if ($cfg.Productivity.WizTree)    { Install-Pkg "WizTree"       "WizTree.WizTree"            } else { Write-Skip "WizTree (disabled)"     }
if ($cfg.Productivity.AutoHotkey) { Install-Pkg "AutoHotkey v2" "AutoHotkey.AutoHotkey"      } else { Write-Skip "AutoHotkey (disabled)"  }
if ($cfg.Productivity.DrawIO)    { Install-Pkg "draw.io"       "JGraph.Draw"                 } else { Write-Skip "draw.io (disabled)"    }
if ($cfg.Productivity.OBSStudio) { Install-Pkg "OBS Studio"    "OBSProject.OBSStudio"       } else { Write-Skip "OBS Studio (disabled)" }

# =============================================================================
# 12. BROWSERS
# =============================================================================
Write-Step "Browsers"

if ($cfg.Browsers.Chrome)     { Install-Pkg "Google Chrome"             "Google.Chrome"                     } else { Write-Skip "Chrome (disabled)"      }
if ($cfg.Browsers.FirefoxDev) { Install-Pkg "Firefox Developer Edition" "Mozilla.Firefox.DeveloperEdition"  } else { Write-Skip "Firefox Dev (disabled)" }
if ($cfg.Browsers.Opera)      { Install-Pkg "Opera"                    "Opera.Opera"                        } else { Write-Skip "Opera (disabled)"      }

# =============================================================================
# 13. FONTS
# =============================================================================
Write-Step "Development Fonts"

if ($cfg.Fonts.JetBrainsMono) { Install-Pkg   "JetBrains Mono Nerd Font" "DEVCOM.JetBrainsMonoNerdFont"        } else { Write-Skip "JetBrains Mono (disabled)" }
if ($cfg.Fonts.FiraCode)      { Install-Choco "Fira Code"                "firacode"                            } else { Write-Skip "Fira Code (disabled)"      }
if ($cfg.Fonts.CascadiaCode)  { Install-Choco "Cascadia Code"            "cascadiafonts"                      } else { Write-Skip "Cascadia Code (disabled)"  }
if ($cfg.Fonts.NerdFontsHack) { Install-Choco "Nerd Fonts (Hack)"        "nerdfont-hack"                      } else { Write-Skip "Nerd Fonts Hack (disabled)" }

# =============================================================================
# 14. VS CODE EXTENSIONS
# =============================================================================
Write-Step "VS Code - Extensions"

if (Get-Command code -ErrorAction SilentlyContinue) {
    $ext = $cfg.VSCodeExtensions

    Write-Host "`n  Python / Django" -ForegroundColor DarkCyan
    if ($ext.Python)       { Install-VSExt "ms-python.python"                  } else { Write-Skip "ms-python.python (disabled)"       }
    if ($ext.Pylance)      { Install-VSExt "ms-python.vscode-pylance"          } else { Write-Skip "ms-python.vscode-pylance (disabled)" }
    if ($ext.Debugpy)      { Install-VSExt "ms-python.debugpy"                 } else { Write-Skip "ms-python.debugpy (disabled)"       }
    if ($ext.VscodeDjango) { Install-VSExt "batisteo.vscode-django"            } else { Write-Skip "batisteo.vscode-django (disabled)"  }
    if ($ext.AutoCloseTag) { Install-VSExt "formulahendry.auto-close-tag"      } else { Write-Skip "auto-close-tag (disabled)"          }

    Write-Host "`n  Angular / TypeScript" -ForegroundColor DarkCyan
    if ($ext.NgTemplate)      { Install-VSExt "Angular.ng-template"            } else { Write-Skip "ng-template (disabled)"      }
    if ($ext.TypeScriptNext)  { Install-VSExt "ms-vscode.vscode-typescript-next" } else { Write-Skip "typescript-next (disabled)" }
    if ($ext.ESLint)          { Install-VSExt "dbaeumer.vscode-eslint"         } else { Write-Skip "vscode-eslint (disabled)"    }
    if ($ext.Prettier)        { Install-VSExt "esbenp.prettier-vscode"         } else { Write-Skip "prettier (disabled)"         }

    Write-Host "`n  General" -ForegroundColor DarkCyan
    if ($ext.GitLens)          { Install-VSExt "eamodio.gitlens"                        } else { Write-Skip "gitlens (disabled)"           }
    if ($ext.GitGraph)         { Install-VSExt "mhutchie.git-graph"                     } else { Write-Skip "git-graph (disabled)"          }
    if ($ext.DockerExt)        { Install-VSExt "ms-azuretools.vscode-docker"            } else { Write-Skip "vscode-docker (disabled)"      }
    if ($ext.RemoteContainers) { Install-VSExt "ms-vscode-remote.remote-containers"     } else { Write-Skip "remote-containers (disabled)"  }
    if ($ext.RemoteWSL)        { Install-VSExt "ms-vscode-remote.remote-wsl"            } else { Write-Skip "remote-wsl (disabled)"          }
    if ($ext.MaterialIcons)    { Install-VSExt "PKief.material-icon-theme"              } else { Write-Skip "material-icons (disabled)"      }
    if ($ext.IndentRainbow)    { Install-VSExt "oderwat.indent-rainbow"                 } else { Write-Skip "indent-rainbow (disabled)"      }
    if ($ext.SpellChecker)     { Install-VSExt "streetsidesoftware.code-spell-checker"  } else { Write-Skip "spell-checker (disabled)"       }
} else {
    Write-Warn "VS Code not found in PATH - extensions skipped."
    Write-Warn "Restart the terminal and run: powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1"
}

# =============================================================================
# 15. SET POWERSHELL 7 AS DEFAULT TERMINAL
# =============================================================================
Write-Step "PowerShell 7 as default terminal"

if ($cfg.Terminal.SetPowerShell7AsDefault) {

    # --- Windows Terminal ---
    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtDone = $false
    foreach ($wtPath in $wtPaths) {
        if (-not (Test-Path $wtPath)) { continue }
        try {
            $wt  = Get-Content $wtPath -Raw | ConvertFrom-Json
            $ps7 = $wt.profiles.list | Where-Object {
                $_.source -eq "Windows.Terminal.PowershellCore"
            } | Select-Object -First 1

            if ($ps7 -and $ps7.guid) {
                if ($wt.defaultProfile -ne $ps7.guid) {
                    $wt.defaultProfile = $ps7.guid
                    $wt | ConvertTo-Json -Depth 20 | Set-Content $wtPath -Encoding UTF8
                    Write-OK "Windows Terminal default -> PowerShell 7"
                } else {
                    Write-Skip "Windows Terminal: PowerShell 7 already default"
                }
            } else {
                Write-Warn "Windows Terminal: PS7 profile not found - open Terminal once after install, then rerun"
            }
            $wtDone = $true
        } catch {
            Write-Warn "Windows Terminal settings update failed: $_"
            $wtDone = $true
        }
        break
    }
    if (-not $wtDone) {
        Write-Warn "Windows Terminal settings.json not found - open it once after install, then rerun"
    }

    # --- VS Code ---
    $vsSettingsPath = "$env:APPDATA\Code\User\settings.json"
    $vsSettingsDir  = Split-Path $vsSettingsPath

    if (-not (Test-Path $vsSettingsDir)) {
        New-Item -ItemType Directory -Path $vsSettingsDir -Force | Out-Null
    }

    if (-not (Test-Path $vsSettingsPath)) {
        '{ "terminal.integrated.defaultProfile.windows": "PowerShell" }' |
            Set-Content $vsSettingsPath -Encoding UTF8
        Write-OK "VS Code settings.json created, default terminal -> PowerShell 7"
    } else {
        try {
            $vs = Get-Content $vsSettingsPath -Raw | ConvertFrom-Json
            if ($vs.'terminal.integrated.defaultProfile.windows' -ne "PowerShell") {
                $vs | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" `
                                 -NotePropertyValue "PowerShell" -Force
                $vs | ConvertTo-Json -Depth 20 | Set-Content $vsSettingsPath -Encoding UTF8
                Write-OK "VS Code default terminal -> PowerShell 7"
            } else {
                Write-Skip "VS Code: PowerShell 7 already default terminal"
            }
        } catch {
            Write-Warn "VS Code settings.json could not be parsed (JSONC?) - add manually:"
            Write-Warn '  "terminal.integrated.defaultProfile.windows": "PowerShell"'
        }
    }

} else {
    Write-Skip "PowerShell 7 as default terminal (disabled in config)"
}

# =============================================================================
# 16. UTILITIES
# =============================================================================
Write-Step "Utilities"

if ($cfg.Utilities.SevenZip)  { Install-Pkg "7-Zip"     "7zip.7zip"                     } else { Write-Skip "7-Zip (disabled)"              }
if ($cfg.Utilities.WinRAR)    { Install-Pkg "WinRAR"    "RARLab.WinRAR"                 } else { Write-Skip "WinRAR (disabled)"             }
if ($cfg.Utilities.VLC)       { Install-Pkg "VLC"       "VideoLAN.VLC"                  } else { Write-Skip "VLC (disabled)"                }
if ($cfg.Utilities.WinSCP)    { Install-Pkg "WinSCP"    "WinSCP.WinSCP"                 } else { Write-Skip "WinSCP (disabled)"             }
if ($cfg.Utilities.PuTTY)     { Install-Pkg "PuTTY"     "PuTTY.PuTTY"                   } else { Write-Skip "PuTTY (disabled)"              }
if ($cfg.Utilities.NotepadPP) { Install-Pkg "Notepad++" "Notepad++.Notepad++"           } else { Write-Skip "Notepad++ (disabled)"          }
if ($cfg.Utilities.VCRedist) {
    Install-Pkg "VC++ Redist x64" "Microsoft.VCRedist.2015+.x64"
    Install-Pkg "VC++ Redist x86" "Microsoft.VCRedist.2015+.x86"
} else { Write-Skip "VC++ Redistributables (disabled)" }

# =============================================================================
# GIT CONFIGURATION
# =============================================================================
Write-Step "Git Configuration"

# --- Symlink the shared .gitconfig (git/) to $HOME/.gitconfig -------------
$repoGitConfig = Join-Path $RepoRoot "git\.gitconfig"
$homeGitConfig = Join-Path $env:USERPROFILE ".gitconfig"

if (Test-Path $repoGitConfig) {
    $existing = Get-Item -Path $homeGitConfig -Force -ErrorAction SilentlyContinue
    $isCorrectSymlink = $existing -and $existing.LinkType -eq "SymbolicLink" -and
        ($existing.Target -contains $repoGitConfig)

    if ($isCorrectSymlink) {
        Write-Skip "$homeGitConfig already symlinked to repo .gitconfig"
    } else {
        if ($existing) {
            $backupPath = "$homeGitConfig.bak"
            Move-Item -Path $homeGitConfig -Destination $backupPath -Force
            Write-Warn "Existing .gitconfig backed up to $backupPath"
        }
        New-Item -ItemType SymbolicLink -Path $homeGitConfig -Target $repoGitConfig -Force | Out-Null
        Write-OK "$homeGitConfig -> $repoGitConfig"
    }
} else {
    Write-Warn "Repo .gitconfig not found at $repoGitConfig - skipping symlink"
}

# --- Identity: written to the untracked ~/.gitconfig.local, never to the ---
# --- tracked/symlinked .gitconfig above -------------------------------------
if ($cfg.Git.UserName -ne "" -or $cfg.Git.UserEmail -ne "") {
    $gitConfigLocal = Join-Path $env:USERPROFILE ".gitconfig.local"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        if ($cfg.Git.UserName -ne "") {
            git config --file $gitConfigLocal user.name $cfg.Git.UserName
            Write-OK "git user.name = $($cfg.Git.UserName)"
        }
        if ($cfg.Git.UserEmail -ne "") {
            git config --file $gitConfigLocal user.email $cfg.Git.UserEmail
            Write-OK "git user.email = $($cfg.Git.UserEmail)"
        }
    } else {
        Write-Warn "git not found in PATH - configure manually after restarting the terminal"
    }
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Installed : $($script:Installed)" -ForegroundColor Green
Write-Host "  Skipped   : $($script:Skipped)"   -ForegroundColor DarkGray

$failColor = "Green"
if ($script:Failed -gt 0) { $failColor = "Red" }
Write-Host "  Failed    : $($script:Failed)" -ForegroundColor $failColor

if ($script:FailList.Count -gt 0) {
    Write-Host ""
    Write-Host "  Failed items:" -ForegroundColor Red
    foreach ($item in $script:FailList) {
        Write-Host "    - $item" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart the computer to apply PATH changes"
Write-Host "  2. Authenticate with GitHub:"
Write-Host "       gh auth login"
Write-Host "  3. Configure WSL:"
Write-Host "       powershell -ExecutionPolicy Bypass -File .\setup-wsl.ps1"
Write-Host ""
