# install-wsl.ps1

> **Requires PowerShell 7.6** as Administrator. Run from the repo root.

Orchestrates the complete WSL 2 installation and configuration.

**What it does:**

1. Enables `WSL` and `VirtualMachinePlatform` Windows features
2. Updates the WSL kernel
3. Sets WSL 2 as default
4. Installs the distro (default: Debian)
5. Copies `wsl/.wslconfig` to `%USERPROFILE%`
6. Injects `wsl/wsl.conf` into `/etc/wsl.conf` inside the distro
7. Restarts WSL to apply configuration
8. Runs `setup-wsl.sh` automatically

```powershell
# Full installation (default)
powershell -ExecutionPolicy Bypass -File .\install-wsl.ps1

# Use a different distro
powershell -ExecutionPolicy Bypass -File .\install-wsl.ps1 -Distro Ubuntu-24.04

# Configure WSL without provisioning
powershell -ExecutionPolicy Bypass -File .\install-wsl.ps1 -SkipProvision:$true
```

> See [Execution Policy](./execution-policy.md) if the command above is blocked.

**If Debian is not yet installed**, the script installs the distro and pauses:

```
[WARN] First run requires creating a user. Launch it manually once before continuing.

  Run: wsl -d Debian
  Create your user and password, then run this script again.
```

Open a new terminal, run `wsl -d Debian`, enter a username and password when prompted, then exit WSL and run the install command again to complete the setup.

On the second run, the script applies the configuration and automatically runs `setup-wsl.sh` inside WSL.
