# wsl.conf

Internal distro configuration, applied at `/etc/wsl.conf`.

Highlights:

- `systemd=true` — required for native Docker and services
- Windows drive mounting with correct permissions (`metadata,uid=1000`)
- `hostname=dev-wsl`
- `appendWindowsPath=true` — allows using `code .` and other Windows binaries in WSL terminal

## Windows shims and shell startup

Because `appendWindowsPath=true` puts `/mnt/c/...` on the PATH, a command without a Linux build can resolve to a **Windows shim** (e.g. `ng` from mise or pnpm on Windows). Such a shim can block for 20s+ when called from WSL, so a `.zshrc` line that runs it at startup (`source <(ng completion script)`) hangs `wsl` before the prompt, while `wsl -e sh` still works because it never reads `.zshrc`.

What the provisioning does about it (`wsl/lib/zsh.sh`):

- `guard_windows_shim_completions` rewrites bare `source <(TOOL completion ...)` lines in `~/.zshrc` (the Angular CLI appends one itself the first time you accept its autocompletion prompt) so they only run for a native Linux `TOOL`, not one under `/mnt/*`.
- `verify_zsh_startup` opens `zsh -ic 'exit 0'` with a 15s limit at the end of the `.zshrc` step and fails the step if it times out.

Diagnose by hand: `type -a ng` (any `/mnt/c/...` hit is a Windows shim) and `timeout 20 zsh -ic 'exit 0'; echo $?` (124 = hang). `provision_node` installs the Angular CLI on Linux (`mise use --global npm:@angular/cli`) and fails if `node`, `pnpm` or `ng` still resolve under `/mnt/`, so the completion loads normally.

Setting `appendWindowsPath=false` would avoid the leak entirely but breaks `code .` and other Windows binaries called by name, so it is not the default here.
