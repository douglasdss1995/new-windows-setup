# Plano de Reestruturação — SOLID + Clean Code

> Status: **Planejado** — nenhuma alteração foi feita no código ainda.

---

## Motivação

O `windows.ps1` atual (~580 linhas) viola os princípios SOLID de várias formas:

| Problema                                                                    | Princípio violado |
| --------------------------------------------------------------------------- | ----------------- |
| Um arquivo controla logging, estado, validações, instalação e orquestração  | SRP               |
| Adicionar uma categoria nova exige editar o arquivo principal               | OCP               |
| Funções de instalação acessam globais em vez de receber só o que precisam   | ISP               |
| O script principal depende de implementações concretas embutidas nele mesmo | DIP               |

---

## Nova Estrutura de Arquivos

```
new-windows-setup/
├── windows.ps1                          # Ponto de entrada (~40 linhas) — só orquestra
├── windows.config.psd1                  # Sem alterações
├── git-clone.ps1                        # Sem alterações
├── git-repos.config.psd1                # Sem alterações
│
├── modules/
│   ├── Logger.ps1                       # Write-Step, Write-OK, Write-Skip, Write-Warn, Write-Fail, Write-Info
│   ├── Stats.ps1                        # Contadores globais + Register-* + Show-SetupSummary
│   ├── Bootstrap.ps1                    # Assert-IsAdministrator, Set-SafeExecutionPolicy, Import-SetupConfig
│   ├── Installer.ps1                    # Install-WingetPackage, Install-ChocoPackage, Install-JetBrainsIde,
│   │                                    # Install-VsCodeExtension, Install-RemoteScript, Add-ProfileLine
│   └── steps/
│       ├── Install-PackageManagers.ps1  # Chocolatey + winget source update
│       ├── Install-Terminal.ps1         # WindowsTerminal, PowerShell 7, Git, OhMyPosh, Starship, zoxide, fzf
│       ├── Install-Editors.ps1          # VSCode, Cursor, JetBrains Toolbox, PyCharm, WebStorm, DataGrip
│       ├── Install-GitTools.ps1         # GitHub CLI, GitKraken, delta
│       ├── Install-Runtimes.ps1         # mise, pyenv-win, nvm, Python, Node, Java, uv, pnpm
│       ├── Install-Database.ps1         # PostgreSQL, DBeaver, TablePlus, pgAdmin, RedisInsight, SQLite Browser
│       ├── Install-Infrastructure.ps1   # Apenas mensagem informativa sobre Docker no WSL (sem installs)
│       ├── Install-ApiTools.ps1         # Postman, Insomnia, Bruno
│       ├── Install-CliTools.ps1         # ripgrep, fd, bat, eza, delta, jq, yq, wget, make, sudo, just, curl
│       ├── Install-Security.ps1         # Bitwarden, Gpg4win, OpenSSH
│       ├── Install-Productivity.ps1     # Obsidian, Notion, Slack, Discord, ShareX, PowerToys, Everything, WizTree, AutoHotkey, DrawIO
│       ├── Install-Utilities.ps1        # 7-Zip, WinRAR, VLC, WinSCP, PuTTY, Notepad++, VC++ Redistributable
│       ├── Install-Browsers.ps1         # Chrome, Firefox Dev
│       ├── Install-Fonts.ps1            # JetBrains Mono, Fira Code, Cascadia Code, Nerd Fonts Hack
│       ├── Install-VsCodeExtensions.ps1 # Todas as extensões VS Code por grupo
│       └── Set-GitConfig.ps1            # git config --global user.name / user.email
│
└── wsl/                                 # Sem alterações
    ├── setup-wsl.ps1
    ├── provision.sh
    └── .wslconfig
```

**Arquivos novos:** 20 (4 módulos core + 16 steps)
**Arquivos reescritos:** 1 (`windows.ps1`)
**Arquivos inalterados:** todos os outros

---

## Mapeamento SOLID

### S — Single Responsibility Principle

Cada arquivo tem exatamente uma razão para mudar:

| Arquivo               | Responsabilidade única                                      |
| --------------------- | ----------------------------------------------------------- |
| `Logger.ps1`          | Formatação de saída no console                              |
| `Stats.ps1`           | Contar resultados e exibir resumo final                     |
| `Bootstrap.ps1`       | Validar o ambiente antes de instalar qualquer coisa         |
| `Installer.ps1`       | Estratégias de instalação (winget, choco, Toolbox, VS Code) |
| `steps/Install-*.ps1` | Instalar uma categoria específica de ferramentas            |
| `windows.ps1`         | Controlar a sequência de execução                           |

### O — Open/Closed Principle

Para adicionar uma nova categoria de ferramentas:

1. Criar `modules/steps/Install-NovaCategoria.ps1` com a função `Install-NovaCategoria`
2. Adicionar uma linha em `windows.ps1`: `Install-NovaCategoria $cfg.NovaCategoria`
3. Adicionar a seção em `windows.config.psd1`

**Nenhum arquivo existente precisa ser modificado.**

### I — Interface Segregation Principle

Cada função de step recebe **apenas a seção de config que usa**:

```powershell
# Antes (acessa cfg inteiro, usa só uma parte):
Install-Terminal   # usava $cfg.Terminal.* mas tinha acesso a $cfg.Database.* etc.

# Depois (recebe só o que precisa):
Install-TerminalTools    $cfg.Terminal
Install-DatabaseTools    $cfg.Database
Install-SecurityTools    $cfg.Security
```

### D — Dependency Inversion Principle

`windows.ps1` depende de **nomes de função** (abstrações), não de implementações:

```powershell
# windows.ps1 não sabe COMO instalar — só sabe QUE deve chamar:
Install-TerminalTools    $cfg.Terminal
Install-Editors          $cfg.Editors
Install-Runtimes         $cfg.Runtimes
# ...
```

As implementações ficam encapsuladas nos módulos.

---

## Decisões Técnicas

### Por que dot-sourcing (`. `) em vez de `Import-Module`?

`Import-Module` com `.psm1` isola o escopo — funções definidas dentro de um módulo não ficam visíveis no caller sem `Export-ModuleMember`. Para um script de setup executado uma única vez, dot-sourcing é mais simples e correto: **todas as funções ficam no mesmo escopo** sem overhead de gerenciamento de módulo.

### Por que `$global:` nos contadores de Stats?

Com dot-sourcing, `$script:` se refere ao script **atualmente em execução**, não ao arquivo onde foi declarado. Então `$script:Installed` dentro de `Installer.ps1` é uma variável diferente de `$script:Installed` em `Stats.ps1`. Usando `$global:StatsInstalled`, `$global:StatsSkipped`, `$global:StatsFailed`, `$global:StatsFailList`, todos os arquivos compartilham os mesmos contadores corretamente.

### Por que capturar `$SetupRoot` no início de `windows.ps1`?

Após o dot-sourcing, `$PSScriptRoot` dentro de `modules/Bootstrap.ps1` apontaria para `modules/`, não para a raiz do projeto. A solução é capturar antes de qualquer dot-source:

```powershell
$SetupRoot = $PSScriptRoot   # capturado antes de qualquer dot-sourcing
. "$SetupRoot\modules\Bootstrap.ps1"
$cfg = Import-SetupConfig -RootPath $SetupRoot
```

---

## Conteúdo Detalhado de Cada Arquivo

### `windows.ps1` (reescrito — ~45 linhas)

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$SetupRoot   = $PSScriptRoot
$ModulesPath = Join-Path $SetupRoot "modules"
$StepsPath   = Join-Path $ModulesPath "steps"

# Módulos core (ordem importa: Logger → Stats → Bootstrap → Installer)
. "$ModulesPath\Logger.ps1"
. "$ModulesPath\Stats.ps1"
. "$ModulesPath\Bootstrap.ps1"
. "$ModulesPath\Installer.ps1"

# Steps (dot-source define as funções; windows.ps1 controla a ordem de execução)
Get-ChildItem -Path $StepsPath -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

# Pré-flight
Set-SafeExecutionPolicy
Assert-IsAdministrator
$cfg = Import-SetupConfig -RootPath $SetupRoot

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Setup - Dev Django + Angular"      -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Execução dos steps (ordem controlada explicitamente aqui)
Install-PackageManagers   $cfg.PackageManagers
Install-TerminalTools     $cfg.Terminal
Install-Editors           $cfg.Editors
Install-GitTools          $cfg.GitTools
Install-Runtimes          $cfg.Runtimes
Install-DatabaseTools     $cfg.Database
Show-InfrastructureInfo
Install-ApiTools          $cfg.API
Install-CliTools          $cfg.CLI
Install-SecurityTools     $cfg.Security
Install-ProductivityApps  $cfg.Productivity
Install-Utilities         $cfg.Utilities
Install-Browsers          $cfg.Browsers
Install-Fonts             $cfg.Fonts
Install-VsCodeExtensions  $cfg.VSCodeExtensions
Set-GitConfig             $cfg.Git

Show-SetupSummary
```

---

### `modules/Logger.ps1`

Responsabilidade: formatação de saída no console. Nenhum estado, nenhuma lógica de negócio.

Funções exportadas:

- `Write-Step([string]$msg)` — cabeçalho de seção (cyan)
- `Write-OK([string]$msg)` — sucesso (green)
- `Write-Skip([string]$msg)` — ignorado (darkgray)
- `Write-Warn([string]$msg)` — aviso (yellow)
- `Write-Fail([string]$msg)` — falha (red)
- `Write-Info([string]$msg)` — informação (darkcyan)

---

### `modules/Stats.ps1`

Responsabilidade: rastrear resultados de instalação e exibir o resumo final.

Variáveis globais inicializadas:

```powershell
$global:StatsInstalled = 0
$global:StatsSkipped   = 0
$global:StatsFailed    = 0
$global:StatsFailList  = @()
```

Funções exportadas:

- `Register-Installed` — incrementa StatsInstalled
- `Register-Skipped` — incrementa StatsSkipped
- `Register-Failed([string]$Name)` — incrementa StatsFailed e adiciona ao FailList
- `Show-SetupSummary` — exibe o resumo e os "next steps"

---

### `modules/Bootstrap.ps1`

Responsabilidade: garantir que o ambiente está correto antes de qualquer instalação.

Funções exportadas:

- `Assert-IsAdministrator` — verifica privilégios de admin; chama `exit 1` se não for admin
- `Set-SafeExecutionPolicy` — ajusta Execution Policy se estiver em Restricted/AllSigned
- `Import-SetupConfig([string]$RootPath)` — valida existência e carrega `windows.config.psd1`; retorna o hashtable `$cfg`

---

### `modules/Installer.ps1`

Responsabilidade: implementar as estratégias de instalação. Cada função usa `Register-*` de Stats.ps1.

Funções exportadas:

**`Install-WingetPackage([string]$Name, [string]$Id, [string]$Extra)`**

- Verifica se já instalado via `winget list --id`
- Instala via `winget install --silent`
- Chama `Register-Installed`, `Register-Skipped` ou `Register-Failed`

**`Install-ChocoPackage([string]$Name, [string]$Pkg)`**

- Verifica com `choco list --local-only`
- Instala com `choco install -y --no-progress`

**`Install-JetBrainsIde([string]$Name, [string]$WingetId, [string]$ToolboxTag)`**

- Verifica se já instalado via winget
- Tenta instalar via Toolbox API (descobre porta pelo `.lock`)
- Fallback para `winget install`

**`Install-VsCodeExtension([string]$Id)`**

- Verifica com `code --list-extensions`
- Instala com `code --install-extension`

**`Install-RemoteScript([string]$Name, [string]$Command, [string]$VerifyCommand)`**

- Executa scripts remotos do padrão `irm url | iex`
- Verifica instalação com `Get-Command $VerifyCommand`
- Usado por: `uv`, `pnpm`

**`Add-ProfileLine([string]$Line, [string]$ProfilePath)`**

- Adiciona uma linha ao perfil do PowerShell se ainda não estiver presente
- Usado por: `mise`

---

### `modules/steps/Install-PackageManagers.ps1`

Função principal: `Install-PackageManagers([hashtable]$Config)`

Funções internas:

- `Install-Chocolatey` — lógica de instalação do Chocolatey (não exportada)

---

### `modules/steps/Install-Terminal.ps1`

Função principal: `Install-TerminalTools([hashtable]$Config)`

Instala via `Install-WingetPackage`: WindowsTerminal, PowerShell, Git, OhMyPosh, Starship, zoxide, fzf.

Se `$Config.SetPowerShell7AsDefault` for verdadeiro, executa lógica de pós-instalação:

- **Windows Terminal**: lê `settings.json` via `ConvertFrom-Json`, localiza o perfil `Windows.Terminal.PowershellCore` e atualiza `defaultProfile` com o seu GUID.
- **VS Code**: lê ou cria `%APPDATA%\Code\User\settings.json` e define `terminal.integrated.defaultProfile.windows = "PowerShell"`.

> **Nota:** ambas as operações são idempotentes — verificam o estado atual antes de gravar.

---

### `modules/steps/Install-Editors.ps1`

Função principal: `Install-Editors([hashtable]$Config)`

Instala:

- VSCode e Cursor via `Install-WingetPackage`
- JetBrains Toolbox via `Install-WingetPackage` (primeiro, para que os IDEs usem a API)
- PyCharm Community, PyCharm Professional, WebStorm, DataGrip via `Install-JetBrainsIde`

---

### `modules/steps/Install-GitTools.ps1`

Função principal: `Install-GitTools([hashtable]$Config)`

Instala: GitHub CLI, GitKraken, delta.

> **Nota:** `delta` está duplicado no config atual (`GitTools.Delta` e `CLI.Delta`). O campo `GitTools.Delta` será mantido no config por compatibilidade mas removido do step — `CLI.Delta` é o canônico.

---

### `modules/steps/Install-Runtimes.ps1`

Função principal: `Install-Runtimes([hashtable]$Config)`

Usa `Install-WingetPackage` para: pyenv-win, nvm-windows, Python 3.13, Node.js LTS, Java 21.

Usa `Install-WingetPackage` + `Add-ProfileLine` para: mise (instala e configura o perfil PS).

Usa `Install-RemoteScript` para: uv, pnpm.

---

### `modules/steps/Install-Database.ps1`

Função principal: `Install-DatabaseTools([hashtable]$Config)`

Instala via `Install-WingetPackage`: PostgreSQL 16, DBeaver, TablePlus, pgAdmin 4, Redis Insight, DB Browser SQLite.

---

### `modules/steps/Install-Infrastructure.ps1`

Função principal: `Show-InfrastructureInfo` (sem parâmetros)

Apenas exibe mensagens informativas sobre Docker no WSL. Nenhuma instalação ocorre.

---

### `modules/steps/Install-ApiTools.ps1`

Função principal: `Install-ApiTools([hashtable]$Config)`

Instala via `Install-WingetPackage`: Postman, Insomnia, Bruno.

---

### `modules/steps/Install-CliTools.ps1`

Função principal: `Install-CliTools([hashtable]$Config)`

Instala via `Install-WingetPackage`: ripgrep, fd, bat, eza, delta, jq, yq, wget, just, curl.

Instala via `Install-ChocoPackage`: make, sudo (gsudo).

---

### `modules/steps/Install-Security.ps1`

Função principal: `Install-SecurityTools([hashtable]$Config)`

Instala via `Install-WingetPackage`: Bitwarden, Gpg4win.

OpenSSH Client: instalado via `Add-WindowsCapability` (lógica interna ao step, não usa `Install-WingetPackage`).

---

### `modules/steps/Install-Productivity.ps1`

Função principal: `Install-ProductivityApps([hashtable]$Config)`

Instala via `Install-WingetPackage`: Obsidian, Notion, Slack, Discord, ShareX, PowerToys, Everything, WizTree, AutoHotkey, draw.io.

---

### `modules/steps/Install-Utilities.ps1`

Função principal: `Install-Utilities([hashtable]$Config)`

Instala via `Install-WingetPackage`: 7-Zip, WinRAR, VLC, WinSCP, PuTTY, Notepad++.

`VCRedist`: caso especial — instala dois pacotes em sequência (`Microsoft.VCRedist.2015+.x64` e `Microsoft.VCRedist.2015+.x86`) com uma única flag `$Config.VCRedist`.

---

### `modules/steps/Install-Browsers.ps1`

Função principal: `Install-Browsers([hashtable]$Config)`

Instala via `Install-WingetPackage`: Google Chrome, Firefox Developer Edition.

---

### `modules/steps/Install-Fonts.ps1`

Função principal: `Install-Fonts([hashtable]$Config)`

Instala via `Install-WingetPackage`: JetBrains Mono Nerd Font.

Instala via `Install-ChocoPackage`: Fira Code, Cascadia Code, Nerd Fonts Hack.

---

### `modules/steps/Install-VsCodeExtensions.ps1`

Função principal: `Install-VsCodeExtensions([hashtable]$Config)`

Guard interno: verifica se `code` está no PATH; exibe `Write-Warn` e retorna se não estiver.

Instala via `Install-VsCodeExtension`: todas as extensões agrupadas por Python/Django, Angular/TypeScript e General.

---

### `modules/steps/Set-GitConfig.ps1`

Função principal: `Set-GitConfig([hashtable]$Config)`

Guard interno: só executa se `$Config.UserName` ou `$Config.UserEmail` não forem vazios.

Aplica `git config --global user.name` e `git config --global user.email`.

---

## Problemas Corrigidos na Reestruturação

| Problema atual                                                | Correção no plano                                                                |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `delta` duplicado em GitTools e CLI                           | Removido de `Install-GitTools.ps1`; `CLI.Delta` é o canônico                     |
| `$script:` não compartilhado entre arquivos                   | Trocado para `$global:StatsInstalled` etc.                                       |
| `$PSScriptRoot` aponta para pasta errada em submódulos        | `$SetupRoot = $PSScriptRoot` capturado em `windows.ps1` e passado como parâmetro |
| `Set-StrictMode` duplicado em submódulos                      | Mantido **apenas** em `windows.ps1`                                              |
| Guard de `code --list-extensions` embutido no fluxo principal | Movido para dentro de `Install-VsCodeExtensions`                                 |
| Lógica de mise/uv/pnpm inline no fluxo principal              | Extraída para `Install-RemoteScript` e `Add-ProfileLine` em `Installer.ps1`      |
| `uv`/`pnpm` falham sem registrar no sumário                  | `Install-RemoteScript` chama `Register-Failed` em caso de falha                 |
| `PyCharm` Community e Pro com mesmo ToolboxTag               | Tags distintos: `"PyCharm"` e `"PyCharmProfessional"`                           |
| Seção "Utilities" sem step correspondente no plano           | Criado `Install-Utilities.ps1` com função `Install-Utilities`                   |
| `SetPowerShell7AsDefault` sem destino na estrutura nova      | Incorporada em `Install-TerminalTools` como pós-instalação condicional          |

---

## O Que NÃO Muda

- `windows.config.psd1` — estrutura e valores idênticos
- `git-clone.ps1` — já bem estruturado, sem alterações
- `git-repos.config.psd1` — sem alterações
- `wsl/setup-wsl.ps1` — sem alterações
- `wsl/provision.sh` — sem alterações
- `wsl/.wslconfig` — sem alterações
- Comportamento externo do script — idêntico ao atual para o usuário final
