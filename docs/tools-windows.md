# Windows Tools

Tools installed on Windows via `windows.ps1` using winget and Chocolatey. All flags are controlled by `windows.config.psd1`.

---

## Package Managers

| Tool | Description |
|---|---|
| [Winget](https://learn.microsoft.com/en-us/windows/package-manager/) | Native Windows package manager (primary installer) |
| [Chocolatey](https://chocolatey.org/) | Complementary package manager for packages not in winget |

---

## Terminal and Shell

| Tool | Description |
|---|---|
| [Windows Terminal](https://aka.ms/terminal) | Modern terminal with multi-shell and multi-tab support |
| [PowerShell 7+](https://github.com/PowerShell/PowerShell) | Modern cross-platform shell (set as default in Terminal and VS Code) |
| [Git Bash](https://gitforwindows.org/) | Bash on Windows with Unix utilities |
| [Oh My Posh](https://ohmyposh.dev/) | Customizable prompt for any shell |
| [Starship](https://starship.rs/) | Fast cross-shell prompt (alternative to Oh My Posh — pick one) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Fast directory navigation (replaces `cd`) |
| [fzf](https://github.com/junegunn/fzf) | Command-line fuzzy finder |

---

## Editors and IDEs

| Tool | Description |
|---|---|
| [VS Code](https://code.visualstudio.com/) | Primary editor for Django and Angular |
| [Cursor](https://cursor.sh/) | AI-powered editor (VS Code fork) |
| [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/) | Manages JetBrains IDE installs, updates and licenses |
| [PyCharm Professional](https://www.jetbrains.com/pycharm/) | Dedicated Python/Django IDE (requires JetBrains license) |
| [WebStorm](https://www.jetbrains.com/webstorm/) | Dedicated JavaScript/TypeScript/Angular IDE (requires license) |
| [DataGrip](https://www.jetbrains.com/datagrip/) | Database IDE (requires JetBrains license) |

---

## VS Code Extensions

### Python / Django

- `ms-python.python` — Python support
- `ms-python.vscode-pylance` — Python language server
- `ms-python.debugpy` — Python debugger
- `batisteo.vscode-django` — Django templates and snippets
- `formulahendry.auto-close-tag` — Automatic tag closing

### Angular / TypeScript

- `Angular.ng-template` — Official Angular support
- `ms-vscode.vscode-typescript-next` — TypeScript next
- `dbaeumer.vscode-eslint` — Integrated ESLint
- `esbenp.prettier-vscode` — Code formatting

### General

- `eamodio.gitlens` — Advanced Git in editor
- `mhutchie.git-graph` — Branch visualization
- `ms-azuretools.vscode-docker` — Docker support
- `ms-vscode-remote.remote-containers` — Dev Containers
- `ms-vscode-remote.remote-wsl` — Develop directly inside WSL
- `PKief.material-icon-theme` — File icons
- `oderwat.indent-rainbow` — Colored indentation
- `streetsidesoftware.code-spell-checker` — Spell checker

---

## Git and Version Control

| Tool | Description |
|---|---|
| [Git](https://git-scm.com/) | Version control |
| [GitHub CLI (gh)](https://cli.github.com/) | Manage GitHub from the command line |
| [GitKraken](https://www.gitkraken.com/) | Visual Git client (optional) |

---

## Runtime and Version Managers

| Tool | Description |
|---|---|
| [mise](https://mise.jdx.dev/) | Universal runtime version manager (Python, Node, Java...) — recommended |
| [pyenv-win](https://github.com/pyenv-win/pyenv-win) | Python version manager for Windows (alternative to mise) |
| [nvm-windows](https://github.com/coreybutler/nvm-windows) | Node.js version manager for Windows (alternative to mise) |
| [uv](https://github.com/astral-sh/uv) | Ultra-fast Python package and environment manager |
| [pnpm](https://pnpm.io/) | Fast and efficient Node package manager |
| [Java JDK 21](https://adoptium.net/) | Java runtime (Eclipse Temurin) |

> `mise`, `uv` and `pnpm` are also installed inside WSL by `provision.sh`.

---

## Databases

| Tool | Description |
|---|---|
| [DBeaver](https://dbeaver.io/) | Universal database client GUI |
| [pgAdmin](https://www.pgadmin.org/) | PostgreSQL administration GUI |
| [TablePlus](https://tableplus.com/) | Modern database client GUI (paid after trial) |
| [Redis Insight](https://redis.com/redis-enterprise/redis-insight/) | GUI for Redis |
| [SQLite Browser](https://sqlitebrowser.org/) | Visual editor for SQLite |
| [PostgreSQL 18](https://www.postgresql.org/) | Native PostgreSQL install (optional — providers in WSL cover most needs) |

---

## API and HTTP Testing

| Tool | Description |
|---|---|
| [Postman](https://www.postman.com/) | Full REST/GraphQL/gRPC client |
| [Insomnia](https://insomnia.rest/) | Alternative REST/GraphQL client |
| [Bruno](https://www.usebruno.com/) | Lightweight open-source file-based HTTP client |

---

## CLI Utilities

| Tool | Description |
|---|---|
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | Ultra-fast file search |
| [fd](https://github.com/sharkdp/fd) | Modern alternative to `find` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern alternative to `ls` |
| [delta](https://github.com/dandavison/delta) | Diff viewer for Git |
| [jq](https://jqlang.github.io/jq/) | JSON processor |
| [yq](https://github.com/mikefarah/yq) | YAML processor |
| [wget](https://www.gnu.org/software/wget/) | File download |
| [make](https://www.gnu.org/software/make/) | Task automation via Makefile |
| [just](https://github.com/casey/just) | Modern alternative to make |
| [curl](https://curl.se/) | HTTP client |
| [sudo](https://github.com/gerardog/gsudo) | `sudo` for Windows (gsudo) |

> All of these are also installed inside WSL by `provision.sh`.

---

## Security and Authentication

| Tool | Description |
|---|---|
| [Bitwarden](https://bitwarden.com/) | Open-source password manager |
| [Gpg4win](https://www.gpg4win.org/) | GPG for Windows — commit signing and encryption |
| [OpenSSH](https://www.openssh.com/) | SSH client/server |

---

## Productivity

| Tool | Description |
|---|---|
| [Obsidian](https://obsidian.md/) | Markdown notes and knowledge management |
| [Notion](https://www.notion.so/) | Documentation and project organization (optional) |
| [Slack](https://slack.com/) | Team communication (install if used at work) |
| [Discord](https://discord.com/) | Community communication (optional) |
| [ShareX](https://getsharex.com/) | Screenshots and screen recording |
| [PowerToys](https://github.com/microsoft/PowerToys) | Windows productivity utilities (FancyZones, PowerRename, etc.) |
| [Everything](https://www.voidtools.com/) | Instant file search across all drives |
| [WizTree](https://diskanalyzer.com/) | Visual disk usage analyzer |
| [AutoHotkey](https://www.autohotkey.com/) | Keyboard automation and shortcuts (optional) |
| [draw.io](https://www.drawio.com/) | Diagram and flowchart editor |

---

## Utilities

| Tool | Description |
|---|---|
| [7-Zip](https://www.7-zip.org/) | Archive manager (free, open-source) |
| [VLC](https://www.videolan.org/vlc/) | Media player |
| [WinSCP](https://winscp.net/) | SFTP/FTP client |
| [PuTTY](https://www.putty.org/) | SSH/Telnet client |
| [Notepad++](https://notepad-plus-plus.org/) | Lightweight text editor |
| [Visual C++ Redistributables](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist) | Runtime required by many native packages |

---

## Browsers

| Tool | Description |
|---|---|
| [Chrome](https://www.google.com/chrome/) | Web development — DevTools |
| [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) | Advanced dev tools and CSS Grid inspector |
| [Opera](https://www.opera.com/) | Alternative browser — built-in VPN and ad blocker (disabled by default) |

---

## Development Fonts

| Font | Description |
|---|---|
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) | Monospace font with ligatures |
| [Fira Code](https://github.com/tonsky/FiraCode) | Font with programming ligatures |
| [Cascadia Code](https://github.com/microsoft/cascadia-code) | Microsoft font with ligatures |
| [Hack Nerd Font](https://www.nerdfonts.com/) | Nerd Font variant with icons for terminal prompts |
