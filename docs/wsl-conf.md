# wsl.conf

Internal distro configuration, applied at `/etc/wsl.conf`.

Highlights:

- `systemd=true` — required for native Docker and services
- Windows drive mounting with correct permissions (`metadata,uid=1000`)
- `hostname=dev-wsl`
- `appendWindowsPath=true` — allows using `code .` and other Windows binaries in WSL terminal
