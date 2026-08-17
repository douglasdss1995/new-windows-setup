# setup-windows.ps1

Installs all tools listed in [`docs/tools-windows.md`](./tools-windows.md) using **winget** (primary) and **Chocolatey** (complement).

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

> Run as Administrator. See [Execution Policy](./execution-policy.md) if the command above is blocked.

| Category | Examples                                                       |
| -------- | --------------------------------------------------------------- |
| Terminal | Windows Terminal, PowerShell 7, Git Bash, Oh My Posh, Starship |

> Oh My Posh is enabled by default and activated automatically in your PowerShell profile using the `amro` theme (`windows/themes/amro.omp.json`). To customize, edit that file directly, or add another `*.omp.json` file to `windows/themes/` and point `Terminal.OhMyPoshTheme` at it in `windows/windows.config.psd1`.

| Editors      | VS Code, Cursor, PyCharm Community, WebStorm                      |
| Runtimes     | mise, pyenv-win, nvm, Python, Node LTS, JDK 21, uv, pnpm          |
| Databases    | PostgreSQL, DBeaver, TablePlus, pgAdmin, Redis Insight            |
| Docker       | Docker Engine in WSL (via `setup-wsl.sh`) + providers compose     |
| API          | Postman, Insomnia, Bruno                                          |
| CLI          | ripgrep, fd, bat, eza, fzf, zoxide, jq, delta, just               |
| Security     | Bitwarden, Gpg4win, OpenSSH                                       |
| Productivity | PowerToys, Obsidian, ShareX, Everything, AutoHotkey               |
| Browsers     | Chrome, Firefox Developer Edition, Opera (opt-in)                 |
| Fonts        | JetBrains Mono Nerd, Fira Code, Cascadia Code                     |
| VS Code      | 18 extensions for Python/Django, Angular/TS and general utilities |

At the end of execution the script displays:

```
Next steps:
  1. Restart the computer to apply PATH changes
  2. Authenticate with GitHub:
       gh auth login
  3. Configure WSL:
       powershell -ExecutionPolicy Bypass -File .\setup-wsl.ps1
```
