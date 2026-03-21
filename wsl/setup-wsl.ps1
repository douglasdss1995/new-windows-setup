# =============================================================================
# setup-wsl.ps1 — Instalação e configuração do WSL 2 + Ubuntu
# Executar como Administrador no PowerShell
# Uso: .\setup-wsl.ps1 [-Distro ubuntu-24.04] [-SkipProvision]
# =============================================================================

param(
    [string]$Distro      = "Ubuntu-24.04",
    [switch]$SkipProvision
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Write-Step  { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[OK] $msg"   -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[ERRO] $msg" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------------------
# Verificar execução como Administrador
# -----------------------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Execute este script como Administrador (clique direito > Executar como Administrador)"
}

# -----------------------------------------------------------------------------
# 1. Habilitar recursos do Windows necessários
# -----------------------------------------------------------------------------
Write-Step "Habilitando recursos do Windows"

$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform"
)

foreach ($feature in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
    if ($state -ne "Enabled") {
        Write-Host "  Habilitando $feature..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
        Write-OK "$feature habilitado"
    } else {
        Write-OK "$feature já habilitado"
    }
}

# -----------------------------------------------------------------------------
# 2. Atualizar o kernel do WSL
# -----------------------------------------------------------------------------
Write-Step "Atualizando kernel do WSL"
wsl --update
Write-OK "Kernel WSL atualizado"

# -----------------------------------------------------------------------------
# 3. Definir WSL 2 como padrão
# -----------------------------------------------------------------------------
Write-Step "Definindo WSL 2 como padrão"
wsl --set-default-version 2
Write-OK "WSL 2 definido como padrão"

# -----------------------------------------------------------------------------
# 4. Instalar a distro
# -----------------------------------------------------------------------------
Write-Step "Verificando distro: $Distro"

$installedDistros = wsl --list --quiet 2>$null
$isInstalled = $installedDistros -match [regex]::Escape($Distro)

if (-not $isInstalled) {
    Write-Host "  Instalando $Distro..." -ForegroundColor Yellow
    wsl --install -d $Distro --no-launch
    Write-OK "$Distro instalado"
    Write-Warn "Primeira execução requer criação de usuário. Inicie manualmente uma vez antes de continuar."
    Write-Host "`n  Execute: wsl -d $Distro" -ForegroundColor Cyan
    Write-Host "  Crie seu usuário e senha, depois execute este script novamente com -SkipProvision:$false`n"
    exit 0
} else {
    Write-OK "$Distro já instalado"
}

# -----------------------------------------------------------------------------
# 5. Copiar .wslconfig para o perfil do usuário
# -----------------------------------------------------------------------------
Write-Step "Instalando .wslconfig"

$wslConfigSrc = Join-Path $PSScriptRoot ".wslconfig"
$wslConfigDst = Join-Path $env:USERPROFILE ".wslconfig"

if (Test-Path $wslConfigSrc) {
    Copy-Item -Path $wslConfigSrc -Destination $wslConfigDst -Force
    Write-OK ".wslconfig copiado para $wslConfigDst"
} else {
    Write-Warn ".wslconfig não encontrado em $wslConfigSrc — pulando"
}

# -----------------------------------------------------------------------------
# 6. Copiar wsl.conf para dentro da distro
# -----------------------------------------------------------------------------
Write-Step "Configurando wsl.conf na distro"

$wslConfSrc = Join-Path $PSScriptRoot "wsl.conf"

if (Test-Path $wslConfSrc) {
    $wslConfContent = Get-Content $wslConfSrc -Raw
    # Escreve o arquivo dentro do WSL via stdin
    $wslConfContent | wsl -d $Distro -- bash -c "sudo tee /etc/wsl.conf > /dev/null"
    Write-OK "wsl.conf configurado em /etc/wsl.conf"
} else {
    Write-Warn "wsl.conf não encontrado em $wslConfSrc — pulando"
}

# -----------------------------------------------------------------------------
# 7. Reiniciar o WSL para aplicar configurações
# -----------------------------------------------------------------------------
Write-Step "Reiniciando WSL para aplicar configurações"
wsl --shutdown
Start-Sleep -Seconds 2
Write-OK "WSL reiniciado"

# -----------------------------------------------------------------------------
# 8. Copiar e executar o provision.sh dentro do WSL
# -----------------------------------------------------------------------------
if (-not $SkipProvision) {
    Write-Step "Executando provision.sh na distro $Distro"

    $provisionSrc = Join-Path $PSScriptRoot "provision.sh"

    if (-not (Test-Path $provisionSrc)) {
        Write-Fail "provision.sh não encontrado em $provisionSrc"
    }

    # Converter caminho Windows para path WSL
    $provisionWslPath = wsl -d $Distro -- wslpath -u "$provisionSrc"
    $provisionWslPath = $provisionWslPath.Trim()

    # Garantir permissão de execução e rodar
    wsl -d $Distro -- bash -c "chmod +x '$provisionWslPath' && bash '$provisionWslPath'"

    Write-OK "provision.sh executado com sucesso"
} else {
    Write-Warn "Provisionamento pulado (-SkipProvision)"
}

# -----------------------------------------------------------------------------
# Concluído
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  WSL configurado com sucesso!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Para abrir o WSL:"
Write-Host "  wsl -d $Distro" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para abrir no Windows Terminal:"
Write-Host "  Clique na seta do terminal e selecione $Distro" -ForegroundColor Cyan
Write-Host ""
