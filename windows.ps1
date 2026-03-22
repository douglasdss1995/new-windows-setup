# =============================================================================
# windows.ps1 - Setup completo para Windows recem-formatado
# Baseado em ferramentas.md - Dev Django + Angular
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File windows.ps1
#
# Edite windows.config.psd1 para ativar/desativar ferramentas e configurar Git.
# Requer execucao como Administrador.
# Compativel com PowerShell 5.1+
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
# Carregar configuracoes
# -----------------------------------------------------------------------------
$ConfigFile = Join-Path $PSScriptRoot "windows.config.psd1"

if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERRO] Arquivo de configuracao nao encontrado: $ConfigFile" -ForegroundColor Red
    Write-Host "       Crie o arquivo windows.config.psd1 na mesma pasta do script." -ForegroundColor Yellow
    exit 1
}

$cfg = Import-PowerShellDataFile -Path $ConfigFile
Write-Host ""
Write-Host "  Configuracao carregada: $ConfigFile" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# Verificar Execution Policy
# -----------------------------------------------------------------------------
$pol = Get-ExecutionPolicy -Scope CurrentUser
if ($pol -eq "Restricted" -or $pol -eq "AllSigned") {
    Write-Warn "Execution Policy bloqueada ($pol) - ajustando para RemoteSigned..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-OK "Execution Policy ajustada"
}

# -----------------------------------------------------------------------------
# Verificar Administrador
# -----------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[ERRO] Execute como Administrador." -ForegroundColor Red
    Write-Host "       Clique com botao direito no PowerShell > 'Executar como administrador'" -ForegroundColor Red
    Write-Host "       Depois execute: powershell -ExecutionPolicy Bypass -File windows.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# -----------------------------------------------------------------------------
# Funcao: instalar via winget
# -----------------------------------------------------------------------------
function Install-Pkg {
    param(
        [string]$Name,
        [string]$Id,
        [string]$Extra
    )

    $check = winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
    if ($check -match [regex]::Escape($Id)) {
        Write-Skip "$Name (ja instalado)"
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
        Write-Fail "$Name (codigo $LASTEXITCODE)"
        $script:FailList += $Name
        $script:Failed++
    }
}

# -----------------------------------------------------------------------------
# Funcao: instalar via Chocolatey
# -----------------------------------------------------------------------------
function Install-Choco {
    param([string]$Name, [string]$Pkg)

    $list = choco list --local-only $Pkg 2>&1 | Out-String
    if ($list -match $Pkg) {
        Write-Skip "$Name (ja instalado)"
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
# Funcao: instalar extensao VS Code
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
Write-Host "  Setup Windows - Dev Django + Angular" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# =============================================================================
# 1. GERENCIADORES DE PACOTES
# =============================================================================
Write-Step "Gerenciadores de Pacotes"

Write-Info "Atualizando fontes do winget..."
winget source update 2>&1 | Out-Null

if ($cfg.PackageManagers.Chocolatey) {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Skip "Chocolatey (ja instalado)"
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
    Write-Skip "Chocolatey (desativado no config)"
    $script:Skipped++
}

# =============================================================================
# 2. TERMINAL E SHELL
# =============================================================================
Write-Step "Terminal e Shell"

if ($cfg.Terminal.WindowsTerminal) { Install-Pkg "Windows Terminal"  "Microsoft.WindowsTerminal" } else { Write-Skip "Windows Terminal (desativado)" }
if ($cfg.Terminal.PowerShell7)     { Install-Pkg "PowerShell 7"      "Microsoft.PowerShell"      } else { Write-Skip "PowerShell 7 (desativado)"  }
if ($cfg.Terminal.Git)             { Install-Pkg "Git + Git Bash"    "Git.Git"                   } else { Write-Skip "Git (desativado)"           }
if ($cfg.Terminal.OhMyPosh)        { Install-Pkg "Oh My Posh"        "JanDeDobbeleer.OhMyPosh"   } else { Write-Skip "Oh My Posh (desativado)"   }
if ($cfg.Terminal.Starship)        { Install-Pkg "Starship"          "Starship.Starship"          } else { Write-Skip "Starship (desativado)"     }
if ($cfg.Terminal.Zoxide)          { Install-Pkg "zoxide"            "ajeetdsouza.zoxide"         } else { Write-Skip "zoxide (desativado)"       }
if ($cfg.Terminal.Fzf)             { Install-Pkg "fzf"               "junegunn.fzf"               } else { Write-Skip "fzf (desativado)"         }

# =============================================================================
# 3. EDITORES E IDEs
# =============================================================================
Write-Step "Editores e IDEs"

if ($cfg.Editors.VSCode)   { Install-Pkg "VS Code"           "Microsoft.VisualStudioCode"      } else { Write-Skip "VS Code (desativado)"   }
if ($cfg.Editors.Cursor)   { Install-Pkg "Cursor"            "Anysphere.Cursor"                 } else { Write-Skip "Cursor (desativado)"   }
if ($cfg.Editors.PyCharm)  { Install-Pkg "PyCharm Community" "JetBrains.PyCharm.Community"     } else { Write-Skip "PyCharm (desativado)"  }
if ($cfg.Editors.WebStorm) { Install-Pkg "WebStorm"          "JetBrains.WebStorm"              } else { Write-Skip "WebStorm (desativado)" }

# =============================================================================
# 4. GIT E CONTROLE DE VERSAO
# =============================================================================
Write-Step "Git e Controle de Versao"

if ($cfg.GitTools.GitHubCLI)  { Install-Pkg "GitHub CLI"  "GitHub.cli"          } else { Write-Skip "GitHub CLI (desativado)"  }
if ($cfg.GitTools.GitKraken)  { Install-Pkg "GitKraken"   "Axosoft.GitKraken"   } else { Write-Skip "GitKraken (desativado)"  }
if ($cfg.GitTools.Delta)      { Install-Pkg "delta"        "dandavison.delta"    } else { Write-Skip "delta (desativado)"      }

# =============================================================================
# 5. RUNTIMES E GERENCIADORES DE VERSAO
# =============================================================================
Write-Step "Runtimes e Gerenciadores de Versao"

if ($cfg.Runtimes.Mise)       { Install-Pkg "mise"                   "jdx.mise"                        } else { Write-Skip "mise (desativado)"       }
if ($cfg.Runtimes.PyenvWin)   { Install-Pkg "pyenv-win"              "pyenv-win.pyenv-win"              } else { Write-Skip "pyenv-win (desativado)"   }
if ($cfg.Runtimes.NvmWindows) { Install-Pkg "nvm-windows"            "CoreyButler.NVMforWindows"        } else { Write-Skip "nvm-windows (desativado)" }
if ($cfg.Runtimes.Python313)  { Install-Pkg "Python 3.13"            "Python.Python.3.13"               } else { Write-Skip "Python 3.13 (desativado)" }
if ($cfg.Runtimes.NodeLTS)    { Install-Pkg "Node.js LTS"            "OpenJS.NodeJS.LTS"                } else { Write-Skip "Node.js LTS (desativado)" }
if ($cfg.Runtimes.Java21)     { Install-Pkg "Eclipse Temurin 21 JDK" "EclipseAdoptium.Temurin.21.JDK"  } else { Write-Skip "Java 21 (desativado)"     }

if ($cfg.Runtimes.Uv) {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Skip "uv (ja instalado)"
        $script:Skipped++
    } else {
        Write-Host "  --> uv..." -ForegroundColor White
        powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
        if (Get-Command uv -ErrorAction SilentlyContinue) {
            Write-OK "uv"
            $script:Installed++
        } else {
            Write-Warn "uv - reinicie o terminal e verifique se foi instalado"
        }
    }
} else {
    Write-Skip "uv (desativado)"
}

if ($cfg.Runtimes.Pnpm) {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Skip "pnpm (ja instalado)"
        $script:Skipped++
    } else {
        Write-Host "  --> pnpm..." -ForegroundColor White
        Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            Write-OK "pnpm"
            $script:Installed++
        } else {
            Write-Warn "pnpm - reinicie o terminal e verifique se foi instalado"
        }
    }
} else {
    Write-Skip "pnpm (desativado)"
}

# =============================================================================
# 6. BANCO DE DADOS
# =============================================================================
Write-Step "Banco de Dados"

if ($cfg.Database.PostgreSQL16)  { Install-Pkg "PostgreSQL 16"     "PostgreSQL.PostgreSQL.16"          } else { Write-Skip "PostgreSQL 16 (desativado)"   }
if ($cfg.Database.DBeaver)       { Install-Pkg "DBeaver"           "dbeaver.dbeaver"                   } else { Write-Skip "DBeaver (desativado)"          }
if ($cfg.Database.TablePlus)     { Install-Pkg "TablePlus"         "TablePlus.TablePlus"               } else { Write-Skip "TablePlus (desativado)"        }
if ($cfg.Database.PgAdmin)       { Install-Pkg "pgAdmin 4"         "PostgreSQL.pgAdmin"                } else { Write-Skip "pgAdmin (desativado)"          }
if ($cfg.Database.RedisInsight)  { Install-Pkg "Redis Insight"     "RedisLabs.RedisInsight"            } else { Write-Skip "Redis Insight (desativado)"    }
if ($cfg.Database.SQLiteBrowser) { Install-Pkg "DB Browser SQLite" "DBBrowserForSQLite.DBBrowserForSQLite" } else { Write-Skip "SQLite Browser (desativado)" }

# =============================================================================
# 7. DOCKER E INFRAESTRUTURA
# =============================================================================
Write-Step "Docker e Infraestrutura"

Write-Info "Docker roda via Docker Engine nativo no WSL - sem Docker Desktop."
Write-Info "Execute o script wsl/provision.sh no WSL para instalar e configurar."
Write-Info "Vantagem: ~50-150 MB de RAM vs ~1 GB do Docker Desktop."

# =============================================================================
# 8. API E TESTES HTTP
# =============================================================================
Write-Step "API e Testes HTTP"

if ($cfg.API.Postman)  { Install-Pkg "Postman"  "Postman.Postman"  } else { Write-Skip "Postman (desativado)"  }
if ($cfg.API.Insomnia) { Install-Pkg "Insomnia" "Kong.Insomnia"    } else { Write-Skip "Insomnia (desativado)" }
if ($cfg.API.Bruno)    { Install-Pkg "Bruno"    "Bruno.Bruno"      } else { Write-Skip "Bruno (desativado)"    }

# =============================================================================
# 9. UTILITARIOS CLI
# =============================================================================
Write-Step "Utilitarios de Linha de Comando"

if ($cfg.CLI.Ripgrep) { Install-Pkg "ripgrep" "BurntSushi.ripgrep.MSVC" } else { Write-Skip "ripgrep (desativado)" }
if ($cfg.CLI.Fd)      { Install-Pkg "fd"      "sharkdp.fd"              } else { Write-Skip "fd (desativado)"      }
if ($cfg.CLI.Bat)     { Install-Pkg "bat"     "sharkdp.bat"             } else { Write-Skip "bat (desativado)"     }
if ($cfg.CLI.Eza)     { Install-Pkg "eza"     "eza-community.eza"       } else { Write-Skip "eza (desativado)"     }
if ($cfg.CLI.Delta)   { Install-Pkg "delta"   "dandavison.delta"        } else { Write-Skip "delta (desativado)"   }
if ($cfg.CLI.Jq)      { Install-Pkg "jq"      "jqlang.jq"               } else { Write-Skip "jq (desativado)"      }
if ($cfg.CLI.Yq)      { Install-Pkg "yq"      "MikeFarah.yq"            } else { Write-Skip "yq (desativado)"      }
if ($cfg.CLI.Wget)    { Install-Pkg "wget"    "GnuWin32.Wget"           } else { Write-Skip "wget (desativado)"    }
if ($cfg.CLI.Make)    { Install-Pkg "make"    "GnuWin32.Make"           } else { Write-Skip "make (desativado)"    }
if ($cfg.CLI.Just)    { Install-Pkg "just"    "Casey.Just"              } else { Write-Skip "just (desativado)"    }
if ($cfg.CLI.Curl)    { Install-Pkg "curl"    "cURL.cURL"               } else { Write-Skip "curl (desativado)"    }

# =============================================================================
# 10. SEGURANCA E AUTENTICACAO
# =============================================================================
Write-Step "Seguranca e Autenticacao"

if ($cfg.Security.Bitwarden) { Install-Pkg "Bitwarden" "Bitwarden.Bitwarden" } else { Write-Skip "Bitwarden (desativado)" }
if ($cfg.Security.Gpg4win)   { Install-Pkg "Gpg4win"   "GnuPG.Gpg4win"      } else { Write-Skip "Gpg4win (desativado)"   }

if ($cfg.Security.OpenSSH) {
    $ssh = Get-WindowsCapability -Online -Name "OpenSSH.Client*"
    if ($ssh.State -eq "Installed") {
        Write-Skip "OpenSSH Client (ja instalado)"
        $script:Skipped++
    } else {
        Write-Host "  --> OpenSSH Client..." -ForegroundColor White
        Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" | Out-Null
        Write-OK "OpenSSH Client"
        $script:Installed++
    }
} else {
    Write-Skip "OpenSSH (desativado)"
}

# =============================================================================
# 11. PRODUTIVIDADE
# =============================================================================
Write-Step "Produtividade e Organizacao"

if ($cfg.Productivity.Obsidian)   { Install-Pkg "Obsidian"      "Obsidian.Obsidian"           } else { Write-Skip "Obsidian (desativado)"    }
if ($cfg.Productivity.Notion)     { Install-Pkg "Notion"        "Notion.Notion"               } else { Write-Skip "Notion (desativado)"      }
if ($cfg.Productivity.Slack)      { Install-Pkg "Slack"         "SlackTechnologies.Slack"     } else { Write-Skip "Slack (desativado)"       }
if ($cfg.Productivity.Discord)    { Install-Pkg "Discord"       "Discord.Discord"             } else { Write-Skip "Discord (desativado)"     }
if ($cfg.Productivity.ShareX)     { Install-Pkg "ShareX"        "ShareX.ShareX"              } else { Write-Skip "ShareX (desativado)"      }
if ($cfg.Productivity.PowerToys)  { Install-Pkg "PowerToys"     "Microsoft.PowerToys"        } else { Write-Skip "PowerToys (desativado)"   }
if ($cfg.Productivity.Everything) { Install-Pkg "Everything"    "voidtools.Everything"       } else { Write-Skip "Everything (desativado)"  }
if ($cfg.Productivity.AutoHotkey) { Install-Pkg "AutoHotkey v2" "AutoHotkey.AutoHotkey"      } else { Write-Skip "AutoHotkey (desativado)"  }

# =============================================================================
# 12. NAVEGADORES
# =============================================================================
Write-Step "Navegadores"

if ($cfg.Browsers.Chrome)     { Install-Pkg "Google Chrome"             "Google.Chrome"                     } else { Write-Skip "Chrome (desativado)"      }
if ($cfg.Browsers.FirefoxDev) { Install-Pkg "Firefox Developer Edition" "Mozilla.Firefox.DeveloperEdition"  } else { Write-Skip "Firefox Dev (desativado)" }

# =============================================================================
# 13. FONTES
# =============================================================================
Write-Step "Fontes para Desenvolvimento"

if ($cfg.Fonts.JetBrainsMono) { Install-Pkg   "JetBrains Mono Nerd Font" "DEVCOM.JetBrainsMonoNerdFont"        } else { Write-Skip "JetBrains Mono (desativado)" }
if ($cfg.Fonts.FiraCode)      { Install-Pkg   "Fira Code"                "carrierwaveuploader.FiraCode"        } else { Write-Skip "Fira Code (desativado)"      }
if ($cfg.Fonts.CascadiaCode)  { Install-Pkg   "Cascadia Code"            "Microsoft.CascadiaCode"             } else { Write-Skip "Cascadia Code (desativado)"  }
if ($cfg.Fonts.NerdFontsHack) { Install-Choco "Nerd Fonts (Hack)"        "nerdfont-hack"                      } else { Write-Skip "Nerd Fonts Hack (desativado)" }

# =============================================================================
# 14. VS CODE EXTENSOES
# =============================================================================
Write-Step "VS Code - Extensoes"

if (Get-Command code -ErrorAction SilentlyContinue) {
    $ext = $cfg.VSCodeExtensions

    Write-Host "`n  Python / Django" -ForegroundColor DarkCyan
    if ($ext.Python)       { Install-VSExt "ms-python.python"                  } else { Write-Skip "ms-python.python (desativado)"       }
    if ($ext.Pylance)      { Install-VSExt "ms-python.vscode-pylance"          } else { Write-Skip "ms-python.vscode-pylance (desativado)" }
    if ($ext.Debugpy)      { Install-VSExt "ms-python.debugpy"                 } else { Write-Skip "ms-python.debugpy (desativado)"       }
    if ($ext.VscodeDjango) { Install-VSExt "batisteo.vscode-django"            } else { Write-Skip "batisteo.vscode-django (desativado)"  }
    if ($ext.AutoCloseTag) { Install-VSExt "formulahendry.auto-close-tag"      } else { Write-Skip "auto-close-tag (desativado)"          }

    Write-Host "`n  Angular / TypeScript" -ForegroundColor DarkCyan
    if ($ext.NgTemplate)      { Install-VSExt "Angular.ng-template"            } else { Write-Skip "ng-template (desativado)"      }
    if ($ext.TypeScriptNext)  { Install-VSExt "ms-vscode.vscode-typescript-next" } else { Write-Skip "typescript-next (desativado)" }
    if ($ext.ESLint)          { Install-VSExt "dbaeumer.vscode-eslint"         } else { Write-Skip "vscode-eslint (desativado)"    }
    if ($ext.Prettier)        { Install-VSExt "esbenp.prettier-vscode"         } else { Write-Skip "prettier (desativado)"         }

    Write-Host "`n  Geral" -ForegroundColor DarkCyan
    if ($ext.GitLens)          { Install-VSExt "eamodio.gitlens"                        } else { Write-Skip "gitlens (desativado)"           }
    if ($ext.GitGraph)         { Install-VSExt "mhutchie.git-graph"                     } else { Write-Skip "git-graph (desativado)"          }
    if ($ext.DockerExt)        { Install-VSExt "ms-azuretools.vscode-docker"            } else { Write-Skip "vscode-docker (desativado)"      }
    if ($ext.RemoteContainers) { Install-VSExt "ms-vscode-remote.remote-containers"     } else { Write-Skip "remote-containers (desativado)"  }
    if ($ext.MaterialIcons)    { Install-VSExt "PKief.material-icon-theme"              } else { Write-Skip "material-icons (desativado)"      }
    if ($ext.IndentRainbow)    { Install-VSExt "oderwat.indent-rainbow"                 } else { Write-Skip "indent-rainbow (desativado)"      }
    if ($ext.SpellChecker)     { Install-VSExt "streetsidesoftware.code-spell-checker"  } else { Write-Skip "spell-checker (desativado)"       }
} else {
    Write-Warn "VS Code nao encontrado no PATH - extensoes puladas."
    Write-Warn "Reinicie o terminal e execute: powershell -ExecutionPolicy Bypass -File windows.ps1"
}

# =============================================================================
# CONFIGURACAO DO GIT
# =============================================================================
if ($cfg.Git.UserName -ne "" -or $cfg.Git.UserEmail -ne "") {
    Write-Step "Configuracao do Git"

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
        Write-Warn "git nao encontrado no PATH - configure manualmente apos reiniciar o terminal"
    }
}

# =============================================================================
# RESUMO FINAL
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resumo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Instalados : $($script:Installed)" -ForegroundColor Green
Write-Host "  Ja existiam: $($script:Skipped)"   -ForegroundColor DarkGray

$failColor = "Green"
if ($script:Failed -gt 0) { $failColor = "Red" }
Write-Host "  Falhas     : $($script:Failed)" -ForegroundColor $failColor

if ($script:FailList.Count -gt 0) {
    Write-Host ""
    Write-Host "  Falhou em:" -ForegroundColor Red
    foreach ($item in $script:FailList) {
        Write-Host "    - $item" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Cyan
Write-Host "  1. Reinicie o computador para aplicar alteracoes de PATH"
Write-Host "  2. Autentique no GitHub:"
Write-Host "       gh auth login"
Write-Host "  3. Configure o WSL:"
Write-Host "       cd wsl"
Write-Host "       .\setup-wsl.ps1"
Write-Host ""
