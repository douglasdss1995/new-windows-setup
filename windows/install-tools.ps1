# =============================================================================
# install-tools.ps1 — Instalação de ferramentas para dev Django + Angular
# Executar como Administrador no PowerShell
#
# Uso:
#   .\install-tools.ps1                        # instala tudo
#   .\install-tools.ps1 -Skip Docker,IDEs      # pula categorias
#   .\install-tools.ps1 -Only CLI,Fonts        # instala só categorias
#   .\install-tools.ps1 -DryRun                # mostra o que seria instalado
#
# Categorias disponíveis:
#   PackageManagers, Terminal, Editors, Git, Runtimes, Database,
#   Docker, API, CLI, Security, Productivity, Browsers, Fonts, VSCodeExtensions
#
# -----------------------------------------------------------------------------
# PRÉ-REQUISITO — Execution Policy
# -----------------------------------------------------------------------------
# Se ao tentar executar aparecer o erro:
#   ".\install-tools.ps1 cannot be loaded because running scripts is disabled..."
#
# Execute UMA das opções abaixo (em ordem de preferência):
#
#   Opção A — apenas para a sessão atual (sem risco, sem efeito permanente):
#     powershell -ExecutionPolicy Bypass -File .\install-tools.ps1
#
#   Opção B — para o usuário atual (permanente, sem precisar de Admin):
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#
#   Opção C — para a máquina inteira (requer Admin, mais permissivo):
#     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
#
# RemoteSigned = scripts locais rodam livremente; scripts baixados da internet
# precisam ter assinatura digital. É a política recomendada para desenvolvedores.
# =============================================================================

param(
    [string[]]$Skip    = @(),
    [string[]]$Only    = @(),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Write-Step  { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [OK] $msg"   -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "  [--] $msg"   -ForegroundColor DarkGray }
function Write-Warn  { param($msg) Write-Host "  [!!] $msg"   -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  [XX] $msg"   -ForegroundColor Red }

$script:InstalledCount = 0
$script:SkippedCount   = 0
$script:FailedCount    = 0
$script:FailedList     = @()

function ShouldRun {
    param([string]$Category)
    if ($Only.Count -gt 0) { return $Only -contains $Category }
    return $Skip -notcontains $Category
}

function Install-Winget {
    param(
        [string]$Name,
        [string]$Id,
        [string]$Extra = ""
    )

    if ($DryRun) {
        Write-Host "  [DRY] winget install $Id" -ForegroundColor DarkYellow
        return
    }

    # Verificar se já está instalado
    $check = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $check -match $Id) {
        Write-Skip "$Name (já instalado)"
        $script:SkippedCount++
        return
    }

    Write-Host "  --> Instalando $Name..." -ForegroundColor White
    $cmd = "winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements $Extra"
    Invoke-Expression $cmd

    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Name"
        $script:InstalledCount++
    } else {
        Write-Fail "$Name (winget saiu com código $LASTEXITCODE)"
        $script:FailedList += $Name
        $script:FailedCount++
    }
}

function Install-Choco {
    param([string]$Name, [string]$Package)
    if ($DryRun) {
        Write-Host "  [DRY] choco install $Package" -ForegroundColor DarkYellow
        return
    }
    if ((choco list --local-only $Package 2>$null) -match $Package) {
        Write-Skip "$Name (já instalado)"
        $script:SkippedCount++
        return
    }
    Write-Host "  --> Instalando $Name (choco)..." -ForegroundColor White
    choco install $Package -y --no-progress 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$Name"
        $script:InstalledCount++
    } else {
        Write-Fail "$Name"
        $script:FailedList += $Name
        $script:FailedCount++
    }
}

function Install-VSCodeExt {
    param([string]$ExtId)
    if ($DryRun) {
        Write-Host "  [DRY] code --install-extension $ExtId" -ForegroundColor DarkYellow
        return
    }
    $installed = code --list-extensions 2>$null
    if ($installed -contains $ExtId) {
        Write-Skip "$ExtId"
        $script:SkippedCount++
        return
    }
    code --install-extension $ExtId --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$ExtId"
        $script:InstalledCount++
    } else {
        Write-Fail "$ExtId"
        $script:FailedList += $ExtId
        $script:FailedCount++
    }
}

# -----------------------------------------------------------------------------
# Update-PowerShell — instala ou atualiza para a versão estável mais recente
#
# Usa winget para comparar a versão instalada com a disponível no repositório.
# Funciona corretamente mesmo quando executado a partir do PowerShell 5.1
# (pois consulta o winget em vez de $PSVersionTable).
# Pode ser chamado diretamente para atualizar em qualquer momento:
#   .\install-tools.ps1 -Only Terminal
# -----------------------------------------------------------------------------
function Update-PowerShell {
    $psId = "Microsoft.PowerShell"

    if ($DryRun) {
        Write-Host "  [DRY] winget install/upgrade $psId -> versao estavel mais recente" -ForegroundColor DarkYellow
        return
    }

    # --- Versão instalada (via winget list, regex ancorado ao nome do pacote) -
    $installedRaw   = winget list --id $psId --exact --accept-source-agreements 2>$null | Out-String
    $installedMatch = [regex]::Match($installedRaw, 'Microsoft\.PowerShell\s+(\d+\.\d+\.\d+)')
    $installedVer   = if ($installedMatch.Success) { [Version]$installedMatch.Groups[1].Value } else { $null }

    # --- Versão estável disponível (via winget show) --------------------------
    $availableRaw   = winget show --id $psId --exact --accept-source-agreements 2>$null | Out-String
    $availableMatch = [regex]::Match($availableRaw, 'Version:\s+(\d+\.\d+\.\d+)')
    $availableVer   = if ($availableMatch.Success) { [Version]$availableMatch.Groups[1].Value } else { $null }

    if ($null -eq $availableVer) {
        Write-Warn "PowerShell — nao foi possivel verificar a versao disponivel no winget"
        return
    }

    # Já na versão mais recente — nada a fazer
    if ($null -ne $installedVer -and $installedVer -ge $availableVer) {
        Write-Skip "PowerShell $installedVer (ja esta na versao mais recente estavel)"
        $script:SkippedCount++
        return
    }

    # Determinar ação (install = primeira vez, upgrade = atualização)
    $action  = if ($null -eq $installedVer) { "install" } else { "upgrade" }
    $verb    = if ($action -eq "install") { "Instalando" } else { "Atualizando" }
    $label   = if ($null -eq $installedVer) { "PowerShell $availableVer" } `
               else { "PowerShell $installedVer -> $availableVer" }

    Write-Host "  --> $verb $label..." -ForegroundColor White

    # $null = ... 2>&1 preserva $LASTEXITCODE sem risco de pipeline cmdlet resetar o valor
    $null = & winget $action --id $psId --exact --silent `
        --accept-package-agreements --accept-source-agreements 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-OK $label
        $script:InstalledCount++
    } else {
        Write-Fail "PowerShell — falha em winget $action (codigo $LASTEXITCODE)"
        $script:FailedList += "PowerShell"
        $script:FailedCount++
    }
}

# -----------------------------------------------------------------------------
# Verificar Execution Policy
# -----------------------------------------------------------------------------
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "AllSigned") {
    Write-Host ""
    Write-Host "  [!!] Execution Policy bloqueada: $currentPolicy" -ForegroundColor Yellow
    Write-Host "       Ajustando para RemoteSigned (escopo: CurrentUser)..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "  [OK] Execution Policy ajustada para RemoteSigned" -ForegroundColor Green
    Write-Host ""
}

# -----------------------------------------------------------------------------
# Verificar Admin
# -----------------------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERRO] Execute como Administrador." -ForegroundColor Red
    exit 1
}

if ($DryRun) {
    Write-Host "`n[DRY RUN] Nenhum pacote será instalado.`n" -ForegroundColor DarkYellow
}

# =============================================================================
# 1. GERENCIADORES DE PACOTES
# =============================================================================
if (ShouldRun "PackageManagers") {
    Write-Step "Gerenciadores de Pacotes"

    # Chocolatey
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        if ($DryRun) {
            Write-Host "  [DRY] Instalar Chocolatey" -ForegroundColor DarkYellow
        } else {
            Write-Host "  --> Instalando Chocolatey..." -ForegroundColor White
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-OK "Chocolatey"
            $script:InstalledCount++
        }
    } else {
        Write-Skip "Chocolatey (já instalado)"
        $script:SkippedCount++
    }

    # Atualizar winget sources
    if (-not $DryRun) {
        winget source update 2>$null | Out-Null
    }
}

# =============================================================================
# 2. TERMINAL E SHELL
# =============================================================================
if (ShouldRun "Terminal") {
    Write-Step "Terminal e Shell"
    Install-Winget "Windows Terminal"  "Microsoft.WindowsTerminal"
    Update-PowerShell                  # instala ou atualiza para a ultima estavel
    Install-Winget "Git + Git Bash"    "Git.Git"
    Install-Winget "Oh My Posh"        "JanDeDobbeleer.OhMyPosh"
    Install-Winget "Starship"          "Starship.Starship"
    Install-Winget "zoxide"            "ajeetdsouza.zoxide"
    Install-Winget "fzf"               "junegunn.fzf"
}

# =============================================================================
# 3. EDITORES E IDEs
# =============================================================================
if (ShouldRun "Editors") {
    Write-Step "Editores e IDEs"
    Install-Winget "VS Code"           "Microsoft.VisualStudioCode"
    Install-Winget "Cursor"            "Anysphere.Cursor"
    Install-Winget "PyCharm Community" "JetBrains.PyCharm.Community"
    Install-Winget "WebStorm"          "JetBrains.WebStorm"
}

# =============================================================================
# 4. GIT E CONTROLE DE VERSÃO
# =============================================================================
if (ShouldRun "Git") {
    Write-Step "Git e Controle de Versão"
    Install-Winget "GitHub CLI"        "GitHub.cli"
    Install-Winget "GitKraken"         "Axosoft.GitKraken"
    Install-Winget "delta"             "dandavison.delta"
}

# =============================================================================
# 5. RUNTIMES E GERENCIADORES DE VERSÃO
# =============================================================================
if (ShouldRun "Runtimes") {
    Write-Step "Runtimes e Gerenciadores de Versão"
    Install-Winget "mise"              "jdx.mise"
    Install-Winget "pyenv-win"         "pyenv-win.pyenv-win"
    Install-Winget "nvm-windows"       "CoreyButler.NVMforWindows"
    Install-Winget "Python 3 (latest)" "Python.Python.3.13"
    Install-Winget "Node.js LTS"       "OpenJS.NodeJS.LTS"
    Install-Winget "Eclipse Temurin 21 (JDK)" "EclipseAdoptium.Temurin.21.JDK"

    # uv — instalador oficial
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        if ($DryRun) {
            Write-Host "  [DRY] Instalar uv" -ForegroundColor DarkYellow
        } else {
            Write-Host "  --> Instalando uv..." -ForegroundColor White
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
            Write-OK "uv"
            $script:InstalledCount++
        }
    } else {
        Write-Skip "uv (já instalado)"
        $script:SkippedCount++
    }

    # pnpm
    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        if ($DryRun) {
            Write-Host "  [DRY] Instalar pnpm" -ForegroundColor DarkYellow
        } else {
            Write-Host "  --> Instalando pnpm..." -ForegroundColor White
            Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression
            Write-OK "pnpm"
            $script:InstalledCount++
        }
    } else {
        Write-Skip "pnpm (já instalado)"
        $script:SkippedCount++
    }
}

# =============================================================================
# 6. BANCO DE DADOS
# =============================================================================
if (ShouldRun "Database") {
    Write-Step "Banco de Dados"
    Install-Winget "PostgreSQL 16"     "PostgreSQL.PostgreSQL.16"
    Install-Winget "DBeaver"           "dbeaver.dbeaver"
    Install-Winget "TablePlus"         "TablePlus.TablePlus"
    Install-Winget "pgAdmin 4"         "PostgreSQL.pgAdmin"
    Install-Winget "Redis Insight"     "RedisLabs.RedisInsight"
    Install-Winget "DB Browser SQLite" "DBBrowserForSQLite.DBBrowserForSQLite"
}

# =============================================================================
# 7. DOCKER E INFRAESTRUTURA
# =============================================================================
if (ShouldRun "Docker") {
    Write-Step "Docker e Infraestrutura"
    Write-Host "  [INFO] Docker roda via Docker Engine nativo no WSL — nenhum pacote Windows necessario." -ForegroundColor DarkCyan
    Write-Host "         Execute provision.sh no WSL para instalar e configurar o Docker Engine + providers." -ForegroundColor DarkCyan
    Write-Host "         Vantagem: ~50-150 MB de RAM vs ~1 GB do Docker Desktop." -ForegroundColor DarkCyan
    $script:SkippedCount++
}

# =============================================================================
# 8. API E TESTES HTTP
# =============================================================================
if (ShouldRun "API") {
    Write-Step "API e Testes HTTP"
    Install-Winget "Postman"           "Postman.Postman"
    Install-Winget "Insomnia"          "Kong.Insomnia"
    Install-Winget "Bruno"             "Bruno.Bruno"
}

# =============================================================================
# 9. UTILITÁRIOS CLI
# =============================================================================
if (ShouldRun "CLI") {
    Write-Step "Utilitários de Linha de Comando"
    Install-Winget "ripgrep"           "BurntSushi.ripgrep.MSVC"
    Install-Winget "fd"                "sharkdp.fd"
    Install-Winget "bat"               "sharkdp.bat"
    Install-Winget "eza"               "eza-community.eza"
    Install-Winget "jq"                "jqlang.jq"
    Install-Winget "yq"                "MikeFarah.yq"
    Install-Winget "wget"              "GnuWin32.Wget"
    Install-Winget "make"              "GnuWin32.Make"
    Install-Winget "just"              "Casey.Just"
    Install-Winget "curl"              "cURL.cURL"
}

# =============================================================================
# 10. SEGURANÇA E AUTENTICAÇÃO
# =============================================================================
if (ShouldRun "Security") {
    Write-Step "Segurança e Autenticação"
    Install-Winget "Bitwarden"         "Bitwarden.Bitwarden"
    Install-Winget "Gpg4win"           "GnuPG.Gpg4win"

    # OpenSSH (recurso opcional do Windows)
    if (-not $DryRun) {
        $sshClient = Get-WindowsCapability -Online -Name "OpenSSH.Client*"
        if ($sshClient.State -ne "Installed") {
            Write-Host "  --> Habilitando OpenSSH Client..." -ForegroundColor White
            Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" | Out-Null
            Write-OK "OpenSSH Client"
            $script:InstalledCount++
        } else {
            Write-Skip "OpenSSH Client (já instalado)"
            $script:SkippedCount++
        }
    } else {
        Write-Host "  [DRY] Habilitar OpenSSH Client" -ForegroundColor DarkYellow
    }
}

# =============================================================================
# 11. PRODUTIVIDADE
# =============================================================================
if (ShouldRun "Productivity") {
    Write-Step "Produtividade e Organização"
    Install-Winget "Obsidian"          "Obsidian.Obsidian"
    Install-Winget "Notion"            "Notion.Notion"
    Install-Winget "Slack"             "SlackTechnologies.Slack"
    Install-Winget "Discord"           "Discord.Discord"
    Install-Winget "ShareX"            "ShareX.ShareX"
    Install-Winget "PowerToys"         "Microsoft.PowerToys"
    Install-Winget "Everything"        "voidtools.Everything"
    Install-Winget "AutoHotkey v2"     "AutoHotkey.AutoHotkey"
}

# =============================================================================
# 12. NAVEGADORES
# =============================================================================
if (ShouldRun "Browsers") {
    Write-Step "Navegadores"
    Install-Winget "Google Chrome"             "Google.Chrome"
    Install-Winget "Firefox Developer Edition" "Mozilla.Firefox.DeveloperEdition"
}

# =============================================================================
# 13. FONTES
# =============================================================================
if (ShouldRun "Fonts") {
    Write-Step "Fontes para Desenvolvimento"
    Install-Winget "JetBrains Mono"    "DEVCOM.JetBrainsMonoNerdFont"
    Install-Winget "Fira Code"         "carrierwaveuploader.FiraCode"
    Install-Winget "Cascadia Code"     "Microsoft.CascadiaCode"
    Install-Choco  "Nerd Fonts (Hack)" "nerdfont-hack"
}

# =============================================================================
# 14. VS CODE EXTENSÕES
# =============================================================================
if (ShouldRun "VSCodeExtensions") {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Step "VS Code — Extensões"

        Write-Host "`n  # Python / Django" -ForegroundColor DarkCyan
        Install-VSCodeExt "ms-python.python"
        Install-VSCodeExt "ms-python.vscode-pylance"
        Install-VSCodeExt "ms-python.debugpy"
        Install-VSCodeExt "batisteo.vscode-django"
        Install-VSCodeExt "formulahendry.auto-close-tag"

        Write-Host "`n  # Angular / TypeScript" -ForegroundColor DarkCyan
        Install-VSCodeExt "Angular.ng-template"
        Install-VSCodeExt "ms-vscode.vscode-typescript-next"
        Install-VSCodeExt "dbaeumer.vscode-eslint"
        Install-VSCodeExt "esbenp.prettier-vscode"

        Write-Host "`n  # Geral" -ForegroundColor DarkCyan
        Install-VSCodeExt "eamodio.gitlens"
        Install-VSCodeExt "mhutchie.git-graph"
        Install-VSCodeExt "ms-azuretools.vscode-docker"
        Install-VSCodeExt "ms-vscode-remote.remote-containers"
        Install-VSCodeExt "PKief.material-icon-theme"
        Install-VSCodeExt "oderwat.indent-rainbow"
        Install-VSCodeExt "streetsidesoftware.code-spell-checker"
    } else {
        Write-Warn "VS Code não encontrado — extensões puladas. Instale o VS Code e rode novamente com -Only VSCodeExtensions"
    }
}

# =============================================================================
# RESUMO FINAL
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resumo da instalação" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Instalados : $($script:InstalledCount)" -ForegroundColor Green
Write-Host "  Ja existiam: $($script:SkippedCount)"   -ForegroundColor DarkGray
Write-Host "  Falhas     : $($script:FailedCount)"    -ForegroundColor $(if ($script:FailedCount -gt 0) { "Red" } else { "Green" })

if ($script:FailedList.Count -gt 0) {
    Write-Host "`n  Falhou em:" -ForegroundColor Red
    $script:FailedList | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "Proximos passos recomendados:" -ForegroundColor Cyan
Write-Host "  1. Reinicie o computador para aplicar alteracoes de PATH"
Write-Host "  2. Configure o Git:"
Write-Host "       git config --global user.name 'Seu Nome'"
Write-Host "       git config --global user.email 'seu@email.com'"
Write-Host "  3. Autentique no GitHub: gh auth login"
Write-Host "  4. Configure o WSL:  cd ..\wsl && .\setup-wsl.ps1"
Write-Host ""
