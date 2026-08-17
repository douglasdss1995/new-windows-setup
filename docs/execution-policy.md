# Execution Policy

By default Windows blocks `.ps1` script execution. If you see this error:

```
.\setup-windows.ps1 cannot be loaded because running scripts is disabled on this system.
```

Choose **one** of the options below.

## Option A — Current session only (recommended, no permanent effect)

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

Use this for every script in the repo (`setup-wsl.ps1`, `git-clone.ps1`, etc.) by swapping the file name. It only affects the process that runs the command — nothing changes on the machine, so there's nothing to remember to revert.

## Option B — Current user only (permanent)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

No Admin required. Local scripts run freely; downloaded scripts need a digital signature.

## Option C — Entire machine (requires Admin)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

Applies to all users on the machine.

## Check current policy

```powershell
Get-ExecutionPolicy -List
```

| Policy         | Description                                                |
| -------------- | ----------------------------------------------------------- |
| `Restricted`   | No scripts can run (Windows default)                       |
| `AllSigned`    | Only digitally signed scripts                               |
| `RemoteSigned` | Local scripts free; downloaded need signature               |
| `Bypass`       | Everything runs without restriction                         |
| `Unrestricted` | Everything runs, but shows warning for downloaded scripts   |

> **Note:** `setup-windows.ps1` automatically detects `Restricted` or `AllSigned` policy and adjusts to `RemoteSigned` at `CurrentUser` scope before continuing — but it needs to be called first with **Option A** or via PowerShell as Admin.
