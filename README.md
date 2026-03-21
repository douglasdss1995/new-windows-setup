# new-windows-setup

Automação para configurar uma máquina de desenvolvimento Windows do zero, focada em projetos **Django** (Python) e **Angular** (TypeScript), com suporte a múltiplas linguagens e ferramentas.

---

## Visão Geral

```
new-windows-setup/
├── ferramentas.md              # Catálogo completo de ferramentas recomendadas
├── windows/
│   └── install-tools.ps1      # Instala todas as ferramentas no Windows via winget/choco
└── wsl/
    ├── setup-wsl.ps1           # Habilita e configura o WSL 2 + Ubuntu
    ├── .wslconfig              # Configuração global do WSL (memória, CPU, rede)
    ├── wsl.conf                # Configuração interna da distro Linux
    ├── provision.sh            # Provisiona o ambiente de dev dentro do Ubuntu
    └── providers/              # Referência do compose de serviços compartilhados
        ├── docker-compose.yml
        ├── .env.example
        └── providers/
            ├── postgres/init/01-init-db.sql
            ├── redis/redis.conf
            └── pgadmin/servers.json
```

---

## Pré-requisitos

- Windows 10 (21H2+) ou Windows 11
- PowerShell rodando como **Administrador**
- Conexão com a internet

---

## ⚠️ Execution Policy — Faça isso antes de tudo

Por padrão o Windows bloqueia a execução de scripts `.ps1`. Se ao rodar qualquer script aparecer o erro:

```
.\install-tools.ps1 cannot be loaded because running scripts is disabled on this system.
```

Escolha **uma** das opções abaixo:

### Opção A — Só para a sessão atual (mais seguro, sem efeito permanente)
```powershell
powershell -ExecutionPolicy Bypass -File .\install-tools.ps1
```
> Use esta opção se não quiser alterar a política da máquina. Execute esse comando no lugar de `.\install-tools.ps1` diretamente.

### Opção B — Para o usuário atual (recomendado para devs, permanente)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
> Não precisa de Admin. Scripts locais rodam livremente; scripts baixados da internet precisam ter assinatura digital. **Recomendado.**

### Opção C — Para a máquina inteira (requer Admin)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```
> Aplica para todos os usuários da máquina.

### Verificar a política atual
```powershell
Get-ExecutionPolicy -List
```

| Política | Descrição |
|---|---|
| `Restricted` | Nenhum script pode rodar (padrão do Windows) |
| `AllSigned` | Só scripts com assinatura digital |
| `RemoteSigned` | Scripts locais livres; baixados precisam de assinatura ✅ |
| `Bypass` | Tudo roda sem restrição (use só em sessões isoladas) |
| `Unrestricted` | Tudo roda, mas exibe aviso para scripts baixados |

> **Nota:** O `install-tools.ps1` detecta automaticamente a política `Restricted` ou `AllSigned` e ajusta para `RemoteSigned` no escopo `CurrentUser` antes de prosseguir — mas para isso ele precisa ser chamado primeiro com a **Opção A** ou pelo PowerShell como Admin.

---

## Início Rápido

### Passo 1 — Instalar ferramentas Windows

```powershell
# PowerShell como Administrador
cd windows
.\install-tools.ps1
```

Reinicie o computador após a conclusão para aplicar as alterações de PATH.

### Passo 2 — Configurar o WSL

```powershell
# PowerShell como Administrador
cd wsl
.\setup-wsl.ps1
```

O script instala o Ubuntu 24.04, aplica as configurações e executa automaticamente o `provision.sh` dentro do WSL.

### Passo 3 — Configurações finais

```bash
# Dentro do WSL
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"
gh auth login
```

---

## install-tools.ps1

Instala todas as ferramentas listadas em `ferramentas.md` usando **winget** (primário) e **Chocolatey** (complemento).

| Categoria | Exemplos |
|---|---|
| Terminal | Windows Terminal, PowerShell 7, Git Bash, Oh My Posh, Starship |
| Editores | VS Code, Cursor, PyCharm Community, WebStorm |
| Runtimes | mise, pyenv-win, nvm, Python, Node LTS, JDK 21, uv, pnpm |
| Banco de dados | PostgreSQL, DBeaver, TablePlus, pgAdmin, Redis Insight |
| Docker | Docker Engine no WSL (via `provision.sh`) + providers compose |
| API | Postman, Insomnia, Bruno |
| CLI | ripgrep, fd, bat, eza, fzf, zoxide, jq, delta, just |
| Segurança | Bitwarden, Gpg4win, OpenSSH |
| Produtividade | PowerToys, Obsidian, ShareX, Everything, AutoHotkey |
| Navegadores | Chrome, Firefox Developer Edition |
| Fontes | JetBrains Mono Nerd, Fira Code, Cascadia Code |
| VS Code | 17 extensões para Python/Django, Angular/TS e utilitários gerais |

**Opções disponíveis:**

```powershell
# Instalar tudo
.\install-tools.ps1

# Simular sem instalar nada
.\install-tools.ps1 -DryRun

# Pular categorias específicas
.\install-tools.ps1 -Skip Docker,Browsers,IDEs

# Instalar apenas categorias específicas
.\install-tools.ps1 -Only CLI,Fonts,VSCodeExtensions
```

Categorias: `PackageManagers`, `Terminal`, `Editors`, `Git`, `Runtimes`, `Database`, `Docker`, `API`, `CLI`, `Security`, `Productivity`, `Browsers`, `Fonts`, `VSCodeExtensions`

---

## setup-wsl.ps1

Orquestra a instalação e configuração completa do WSL 2.

**O que faz:**
1. Habilita os recursos `WSL` e `VirtualMachinePlatform` no Windows
2. Atualiza o kernel do WSL
3. Define WSL 2 como padrão
4. Instala a distro (padrão: Ubuntu 24.04)
5. Copia `.wslconfig` para `%USERPROFILE%`
6. Injeta `wsl.conf` em `/etc/wsl.conf` dentro da distro
7. Reinicia o WSL para aplicar as configurações
8. Executa `provision.sh` automaticamente

```powershell
# Instalação completa (padrão)
.\setup-wsl.ps1

# Usar outra distro
.\setup-wsl.ps1 -Distro Ubuntu-22.04

# Só configurar WSL sem provisionar
.\setup-wsl.ps1 -SkipProvision
```

---

## provision.sh

Provisiona o ambiente de desenvolvimento dentro do Ubuntu.

**O que instala:**

| Etapa | Conteúdo |
|---|---|
| Sistema | Dependências de compilação, curl, wget, make |
| Shell | Zsh, Oh My Zsh, plugins (autosuggestions, syntax-highlighting, completions) |
| mise | Gerenciador universal de runtimes |
| Python | Versão latest via mise + uv + poetry, black, ruff, mypy, pytest, ipython |
| Node.js | LTS via mise + pnpm + Angular CLI, ESLint, Prettier |
| CLI | ripgrep, fd, bat, eza, fzf, zoxide, delta, jq, yq, gh |
| Docker | Daemon nativo (sem Docker Desktop) + systemd enable (auto-start) |
| Providers | PostgreSQL, Redis, pgAdmin, Portainer via compose em `~/providers/` |
| Git | Configurado com delta como pager |
| Shell config | `.zshrc` com aliases para Django, Git, Docker, Python, Providers (`pvup`, `pvdown`...) |

**Flags:**

```bash
bash provision.sh                  # tudo
bash provision.sh --skip-docker    # sem Docker
bash provision.sh --skip-python    # sem Python
bash provision.sh --skip-node      # sem Node
```

---

## .wslconfig

Configuração global do WSL, copiada para `%USERPROFILE%\.wslconfig`.

Otimizada para **32 GB RAM / 16 cores**. Ajuste conforme sua máquina:

```ini
[wsl2]
memory=16GB        # 50% da RAM total recomendado
processors=8       # metade dos cores lógicos
swap=4GB
networkingMode=mirrored   # localhost compartilhado Windows ↔ WSL
autoMemoryReclaim=gradual # devolve RAM ao Windows quando ocioso
```

---

## wsl.conf

Configuração interna da distro, aplicada em `/etc/wsl.conf`.

Destaques:
- `systemd=true` — necessário para Docker nativo e serviços
- Montagem dos drives Windows com permissões corretas (`metadata,uid=1000`)
- `hostname=dev-wsl`
- `appendWindowsPath=true` — permite usar `code .` e outros binários Windows no terminal WSL

---

## Providers

O `provision.sh` configura automaticamente os serviços compartilhados em `~/providers/` dentro do WSL e cria um serviço systemd para iniciá-los automaticamente.

| Serviço | URL / Porta | Credenciais padrão |
|---|---|---|
| PostgreSQL | `localhost:5432` | `postgres` / `postgres` |
| Redis | `localhost:6379` | — |
| pgAdmin | http://localhost:5050 | `admin@admin.com` / `admin` |
| Portainer | http://localhost:9000 | (define no primeiro acesso) |

**Aliases disponíveis no shell após o provisionamento:**

```bash
pvup        # docker compose up -d
pvdown      # docker compose down
pvlogs      # docker compose logs -f
pvps        # docker compose ps
pvrestart   # docker compose restart
```

> Edite as senhas padrão em `~/providers/.env` antes de subir os serviços.

---

## Ferramentas

Consulte [`ferramentas.md`](./ferramentas.md) para o catálogo completo com links e descrições de todas as ferramentas recomendadas.

---

## Licença

[MIT](./LICENSE)
