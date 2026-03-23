# =============================================================================
# windows.ps1 - Complete setup for a freshly formatted Windows machine
# Based on ferramentas.md - Dev Django + Angular
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File windows.ps1
#
# Edit windows.config.psd1 to enable/disable tools and configure Git.
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

# -----------------------------------------------------------------------------
# Load configuration
# -----------------------------------------------------------------------------
$ConfigFile = Join-Path $PSScriptRoot "windows.config.psd1"

if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Configuration file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "        Create the windows.config.psd1 file in the same folder as this script." -ForegroundColor Yellow
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
    Write-Host "        Then run: powershell -ExecutionPolicy Bypass -File windows.ps1" -ForegroundColor Yellow
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

# =============================================================================
# 3. EDITORS AND IDEs
# =============================================================================
Write-Step "Editors and IDEs"

if ($cfg.Editors.VSCode)   { Install-Pkg "VS Code"           "Microsoft.VisualStudioCode"      } else { Write-Skip "VS Code (disabled)"   }
if ($cfg.Editors.Cursor)   { Install-Pkg "Cursor"            "Anysphere.Cursor"                 } else { Write-Skip "Cursor (disabled)"   }
if ($cfg.Editors.PyCharm)  { Install-Pkg "PyCharm Community" "JetBrains.PyCharm.Community"     } else { Write-Skip "PyCharm (disabled)"  }
if ($cfg.Editors.WebStorm) { Install-Pkg "WebStorm"          "JetBrains.WebStorm"              } else { Write-Skip "WebStorm (disabled)" }

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

    # Configure mise activation in the PowerShell profile so shims are loaded
    # automatically and `mise use` works per-directory without manually adding
    # %LOCALAPPDATA%\mise\shims to PATH.
    $miseLine = 'mise activate pwsh | Out-String | Invoke-Expression'
    $profilePath = $PROFILE.CurrentUserAllHosts   # %USERPROFILE%\Documents\PowerShell\profile.ps1

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
} else {
    Write-Skip "mise (disabled)"
}

if ($cfg.Runtimes.PyenvWin)   { Install-Pkg "pyenv-win"              "pyenv-win.pyenv-win"              } else { Write-Skip "pyenv-win (disabled)"   }
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

if ($cfg.Database.PostgreSQL16)  { Install-Pkg "PostgreSQL 16"     "PostgreSQL.PostgreSQL.16"          } else { Write-Skip "PostgreSQL 16 (disabled)"   }
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
Write-Info "Run the wsl/provision.sh script inside WSL to install and configure it."
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
if ($cfg.CLI.Wget)    { Install-Pkg "wget"    "GnuWin32.Wget"           } else { Write-Skip "wget (disabled)"    }
if ($cfg.CLI.Make)    { Install-Pkg "make"    "GnuWin32.Make"           } else { Write-Skip "make (disabled)"    }
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
if ($cfg.Productivity.AutoHotkey) { Install-Pkg "AutoHotkey v2" "AutoHotkey.AutoHotkey"      } else { Write-Skip "AutoHotkey (disabled)"  }

# =============================================================================
# 12. BROWSERS
# =============================================================================
Write-Step "Browsers"

if ($cfg.Browsers.Chrome)     { Install-Pkg "Google Chrome"             "Google.Chrome"                     } else { Write-Skip "Chrome (disabled)"      }
if ($cfg.Browsers.FirefoxDev) { Install-Pkg "Firefox Developer Edition" "Mozilla.Firefox.DeveloperEdition"  } else { Write-Skip "Firefox Dev (disabled)" }

# =============================================================================
# 13. FONTS
# =============================================================================
Write-Step "Development Fonts"

if ($cfg.Fonts.JetBrainsMono) { Install-Pkg   "JetBrains Mono Nerd Font" "DEVCOM.JetBrainsMonoNerdFont"        } else { Write-Skip "JetBrains Mono (disabled)" }
if ($cfg.Fonts.FiraCode)      { Install-Pkg   "Fira Code"                "carrierwaveuploader.FiraCode"        } else { Write-Skip "Fira Code (disabled)"      }
if ($cfg.Fonts.CascadiaCode)  { Install-Pkg   "Cascadia Code"            "Microsoft.CascadiaCode"             } else { Write-Skip "Cascadia Code (disabled)"  }
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
    if ($ext.MaterialIcons)    { Install-VSExt "PKief.material-icon-theme"              } else { Write-Skip "material-icons (disabled)"      }
    if ($ext.IndentRainbow)    { Install-VSExt "oderwat.indent-rainbow"                 } else { Write-Skip "indent-rainbow (disabled)"      }
    if ($ext.SpellChecker)     { Install-VSExt "streetsidesoftware.code-spell-checker"  } else { Write-Skip "spell-checker (disabled)"       }
} else {
    Write-Warn "VS Code not found in PATH - extensions skipped."
    Write-Warn "Restart the terminal and run: powershell -ExecutionPolicy Bypass -File windows.ps1"
}

# =============================================================================
# GIT CONFIGURATION
# =============================================================================
if ($cfg.Git.UserName -ne "" -or $cfg.Git.UserEmail -ne "") {
    Write-Step "Git Configuration"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        if ($cfg.Git.UserName -ne "") {
            git config --global user.name $cfg.Git.UserName
            Write-OK "git user.name = $($cfg.Git.UserName)"
        }
        if ($cfg.Git.UserEmail -ne "") {
            git config --global user.email $cfg.Git.UserEmail
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
Write-Host "       cd wsl"
Write-Host "       .\setup-wsl.ps1"
Write-Host ""
