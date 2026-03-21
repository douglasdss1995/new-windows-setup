# Ferramentas para Desenvolvedor Django + Angular

Guia de instalação e configuração de ferramentas para uma máquina de desenvolvimento com foco em Django (Python) e Angular (TypeScript/JavaScript), com suporte a múltiplas linguagens.

---

## Gerenciadores de Pacotes e Runtimes

| Ferramenta | Descrição |
|---|---|
| [Chocolatey](https://chocolatey.org/) | Gerenciador de pacotes para Windows |
| [Winget](https://learn.microsoft.com/pt-br/windows/package-manager/) | Gerenciador de pacotes nativo do Windows |
| [nvm-windows](https://github.com/coreybutler/nvm-windows) | Gerenciador de versões do Node.js |
| [Node.js (LTS)](https://nodejs.org/) | Runtime JavaScript (instalar via nvm) |
| [pyenv-win](https://github.com/pyenv-win/pyenv-win) | Gerenciador de versões do Python |
| [Python 3.x](https://www.python.org/) | Runtime Python (instalar via pyenv) |
| [mise](https://mise.jdx.dev/) | Gerenciador universal de versões de runtimes (Python, Node, Java, Ruby, Go...) |
| [SDKMAN](https://sdkman.io/) | Gerenciador de SDKs JVM (Java, Kotlin, Groovy) |
| [Java JDK](https://adoptium.net/) | Runtime Java (Eclipse Temurin recomendado) |

---

## Terminal e Shell

| Ferramenta | Descrição |
|---|---|
| [Windows Terminal](https://aka.ms/terminal) | Terminal moderno com suporte a múltiplos shells |
| [Git Bash](https://gitforwindows.org/) | Bash no Windows com utilitários Unix |
| [PowerShell 7+](https://github.com/PowerShell/PowerShell) | Shell moderno cross-platform |
| [Oh My Posh](https://ohmyposh.dev/) | Prompt customizável para qualquer shell |
| [Starship](https://starship.rs/) | Prompt cross-shell rápido e configurável |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Navegação rápida entre diretórios (substituto do `cd`) |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder para linha de comando |

---

## Editores e IDEs

| Ferramenta | Descrição |
|---|---|
| [VS Code](https://code.visualstudio.com/) | Editor principal — Django e Angular |
| [PyCharm Community/Professional](https://www.jetbrains.com/pycharm/) | IDE dedicada para Python/Django |
| [WebStorm](https://www.jetbrains.com/webstorm/) | IDE dedicada para JavaScript/TypeScript/Angular |
| [Cursor](https://cursor.sh/) | Editor com IA integrada (fork do VS Code) |

---

## VS Code — Extensões Essenciais

### Python / Django
- `ms-python.python` — Suporte Python
- `ms-python.vscode-pylance` — Language server Python
- `ms-python.debugpy` — Debugger Python
- `batisteo.vscode-django` — Templates e snippets Django
- `formulahendry.auto-close-tag` — Fechamento automático de tags

### Angular / TypeScript
- `Angular.ng-template` — Suporte oficial Angular
- `ms-vscode.vscode-typescript-next` — TypeScript next
- `dbaeumer.vscode-eslint` — ESLint integrado
- `esbenp.prettier-vscode` — Formatação de código

### Geral
- `eamodio.gitlens` — Git avançado no editor
- `mhutchie.git-graph` — Visualização de branches
- `ms-azuretools.vscode-docker` — Suporte Docker
- `ms-vscode-remote.remote-containers` — Dev Containers
- `PKief.material-icon-theme` — Ícones de arquivos
- `oderwat.indent-rainbow` — Indentação colorida
- `streetsidesoftware.code-spell-checker` — Corretor ortográfico

---

## Git e Controle de Versão

| Ferramenta | Descrição |
|---|---|
| [Git](https://git-scm.com/) | Controle de versão |
| [GitHub CLI (gh)](https://cli.github.com/) | Gerenciar GitHub pela linha de comando |
| [GitLens](https://gitkraken.com/gitlens) | Extensão VS Code para Git avançado |
| [GitKraken](https://www.gitkraken.com/) | Cliente Git visual (opcional) |
| [pre-commit](https://pre-commit.com/) | Hooks de Git para validação antes do commit |

---

## Python — Ferramentas de Desenvolvimento

| Ferramenta | Descrição |
|---|---|
| [pip](https://pip.pypa.io/) | Gerenciador de pacotes Python |
| [uv](https://github.com/astral-sh/uv) | Gerenciador de pacotes/ambientes ultrarrápido |
| [pipenv](https://pipenv.pypa.io/) | Ambientes virtuais + dependências |
| [poetry](https://python-poetry.org/) | Gerenciamento moderno de projetos Python |
| [virtualenv](https://virtualenv.pypa.io/) | Ambientes virtuais isolados |
| [black](https://black.readthedocs.io/) | Formatador de código Python |
| [ruff](https://github.com/astral-sh/ruff) | Linter Python ultrarrápido |
| [mypy](https://mypy-lang.org/) | Type checker estático para Python |
| [pytest](https://pytest.org/) | Framework de testes |
| [ipython](https://ipython.org/) | Shell Python interativo melhorado |
| [httpie](https://httpie.io/) | Cliente HTTP para linha de comando |

---

## Node.js / Angular — Ferramentas de Desenvolvimento

| Ferramenta | Descrição |
|---|---|
| [npm](https://www.npmjs.com/) | Gerenciador de pacotes Node |
| [pnpm](https://pnpm.io/) | Gerenciador de pacotes rápido e eficiente |
| [Angular CLI](https://angular.io/cli) | Criação e gerenciamento de projetos Angular |
| [ESLint](https://eslint.org/) | Linter JavaScript/TypeScript |
| [Prettier](https://prettier.io/) | Formatador de código |
| [Jest](https://jestjs.io/) | Framework de testes JavaScript |
| [Nx](https://nx.dev/) | Monorepo e ferramentas de build para Angular |

---

## Banco de Dados

| Ferramenta | Descrição |
|---|---|
| [PostgreSQL](https://www.postgresql.org/) | Banco relacional principal para Django |
| [DBeaver](https://dbeaver.io/) | Cliente universal de banco de dados (GUI) |
| [TablePlus](https://tableplus.com/) | Cliente de banco de dados moderno (GUI) |
| [Redis](https://redis.io/) | Cache, filas e sessões |
| [Redis Insight](https://redis.com/redis-enterprise/redis-insight/) | GUI para Redis |
| [SQLite Browser](https://sqlitebrowser.org/) | Editor visual para SQLite |
| [pgAdmin](https://www.pgadmin.org/) | Administração PostgreSQL (GUI) |

---

## Docker e Infraestrutura

> Docker roda via **Docker Engine nativo no WSL** — sem Docker Desktop. Menor uso de memória, controle total via systemd e inicialização automática com o WSL.

| Ferramenta | Descrição |
|---|---|
| [Docker Engine](https://docs.docker.com/engine/) | Daemon Docker nativo no WSL (sem Docker Desktop) — ~50–150 MB vs ~1 GB do Desktop |
| [Docker Compose](https://docs.docker.com/compose/) | Orquestração de containers local |
| [Portainer](https://www.portainer.io/) | UI web para gerenciar containers Docker (roda via providers compose) |
| [WSL 2](https://learn.microsoft.com/pt-br/windows/wsl/) | Linux no Windows — Docker Engine e providers rodam aqui |

### Providers (Serviços Compartilhados)

Serviços de infraestrutura compartilhados entre projetos, gerenciados via `~/providers/docker-compose.yml` e iniciados automaticamente com o WSL.

| Serviço | Imagem | Porta | Descrição |
|---|---|---|---|
| PostgreSQL | `postgres:15-alpine` | 5432 | Banco relacional principal |
| Redis | `redis:7-alpine` | 6379 | Cache, filas (Celery) e sessões |
| pgAdmin | `dpage/pgadmin4` | 5050 | UI web para PostgreSQL |
| Portainer | `portainer/portainer-ce` | 9000 / 9443 | UI web para gerenciar containers |

> **Redis no compose ou nativo?** Compose. Redis é um serviço de infraestrutura compartilhado (como Postgres), não há ganho em instalá-lo nativamente no WSL. O `redis.conf` limita memória a 256 MB com política `allkeys-lru`, e o ciclo de vida fica consistente com os demais serviços.

---

## API e Testes HTTP

| Ferramenta | Descrição |
|---|---|
| [Postman](https://www.postman.com/) | Cliente REST/GraphQL completo |
| [Insomnia](https://insomnia.rest/) | Cliente REST/GraphQL alternativo |
| [Bruno](https://www.usebruno.com/) | Cliente HTTP open-source baseado em arquivos |
| [curl](https://curl.se/) | Cliente HTTP linha de comando |

---

## Utilitários de Linha de Comando

| Ferramenta | Descrição |
|---|---|
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | Busca em arquivos ultrarrápida |
| [fd](https://github.com/sharkdp/fd) | Alternativa moderna ao `find` |
| [bat](https://github.com/sharkdp/bat) | Alternativa ao `cat` com syntax highlight |
| [eza](https://github.com/eza-community/eza) | Alternativa moderna ao `ls` |
| [delta](https://github.com/dandavison/delta) | Visualizador de diffs para Git |
| [jq](https://jqlang.github.io/jq/) | Processador JSON na linha de comando |
| [yq](https://github.com/mikefarah/yq) | Processador YAML na linha de comando |
| [wget](https://www.gnu.org/software/wget/) | Download de arquivos via linha de comando |
| [make](https://www.gnu.org/software/make/) | Automação de tarefas via Makefile |
| [just](https://github.com/casey/just) | Alternativa moderna ao make |

---

## Segurança e Autenticação

| Ferramenta | Descrição |
|---|---|
| [1Password](https://1password.com/) / [Bitwarden](https://bitwarden.com/) | Gerenciador de senhas |
| [OpenSSH](https://www.openssh.com/) | SSH client/server |
| [GPG (Gpg4win)](https://www.gpg4win.org/) | Assinatura de commits e criptografia |

---

## Produtividade e Organização

| Ferramenta | Descrição |
|---|---|
| [Obsidian](https://obsidian.md/) | Notas em Markdown / gestão de conhecimento |
| [Notion](https://www.notion.so/) | Documentação e organização de projetos |
| [Slack](https://slack.com/) / [Discord](https://discord.com/) | Comunicação com times |
| [ShareX](https://getsharex.com/) | Capturas de tela e gravação de tela |
| [PowerToys](https://github.com/microsoft/PowerToys) | Utilitários produtividade Windows (FancyZones, etc.) |
| [Everything](https://www.voidtools.com/) | Busca ultrarrápida de arquivos no Windows |
| [AutoHotkey](https://www.autohotkey.com/) | Automação e atalhos de teclado no Windows |

---

## Navegadores

| Ferramenta | Descrição |
|---|---|
| [Chrome](https://www.google.com/chrome/) | Desenvolvimento web — DevTools |
| [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) | Ferramentas avançadas de dev |
| [Edge](https://www.microsoft.com/edge) | Alternativa com integração Windows |

---

## Fontes para Desenvolvimento

| Fonte | Descrição |
|---|---|
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) | Fonte monospace para código |
| [Fira Code](https://github.com/tonsky/FiraCode) | Fonte com ligaduras para código |
| [Cascadia Code](https://github.com/microsoft/cascadia-code) | Fonte da Microsoft com ligaduras |
| [Nerd Fonts](https://www.nerdfonts.com/) | Fontes com ícones para terminal |
