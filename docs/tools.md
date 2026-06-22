# Tools

Catalog of tools used in this setup, split by environment.

| Environment | File | Installed by |
|---|---|---|
| Windows | [tools-windows.md](tools-windows.md) | `windows.ps1` via winget / Chocolatey |
| WSL (Ubuntu) | [tools-wsl.md](tools-wsl.md) | `provision.sh` via apt / binary / mise |

> Some tools (mise, uv, pnpm, ripgrep, gh, delta and other CLI utilities) are installed on **both** sides so they are available whether you are working in PowerShell or inside WSL. Each file notes which tools overlap.
