# .wslconfig

Global WSL configuration, copied to `%USERPROFILE%\.wslconfig`.

Optimized for **32 GB RAM / 16 cores**. Adjust for your machine:

```ini
[wsl2]
memory=16GB        # 50% of total RAM recommended
processors=8       # half of logical cores
swap=4GB
networkingMode=nat       # see "Network mode" below — do not switch to mirrored lightly
autoMemoryReclaim=gradual # returns RAM to Windows when idle
```

## Network mode: why NAT, not mirrored

`networkingMode=mirrored` looks tempting — it mirrors the Windows network
interfaces into WSL and is advertised as making `localhost` work more easily
between Windows and WSL. In practice it makes `localhost` **slower**, not
easier, for the common case of a Windows client hitting a container running
in WSL.

**Root cause:** Windows resolves `localhost` as `[::1, 127.0.0.1]` and tries
`::1` first. `mirrored` mode [does not support `::1`][wsl-net-apps] for ports
published from WSL. The connection attempt to `::1` has to time out
(~21 seconds) before Windows falls back to `127.0.0.1`. Every request that
uses `localhost` instead of `127.0.0.1` pays that penalty — measured as
~21.6 s per Python `requests` call and ~114 s total for a chat flow that made
6 requests per answer, dropping to ~8.3 s once pointed at `127.0.0.1`.

**NAT doesn't have this problem:** in NAT mode, the `wslrelay.exe` process on
Windows listens on *both* `127.0.0.1` and `::1` for each port WSL publishes
(check with `Get-NetTCPConnection -LocalPort <port>`), so `localhost`
resolves fast either way (~0.02 s).

### If you must use mirrored mode

Some setups want mirrored for other reasons (e.g. mirroring a LAN IP into
WSL). If so:

1. Know that `localhost` from Windows to a WSL-published port will hang for
   ~21 s per connection until worked around.
2. Either change all affected clients to use `127.0.0.1` instead of
   `localhost`, or apply the Windows IPv6 prefix policy fix below — it makes
   `getaddrinfo("localhost", ...)` return `127.0.0.1` first:

   ```powershell
   # Run as Administrator. Default precedence is 35; this raises IPv4-mapped
   # addresses to 100 so they're preferred over the ::1/128 entry (precedence 50).
   netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 100 4

   # To revert:
   netsh interface ipv6 set prefixpolicy ::ffff:0:0/96 35 4

   # Check current policies:
   netsh interface ipv6 show prefixpolicies
   ```

   This is safe to apply in NAT mode too (harmless there), but is only
   *necessary* for mirrored. It fixes `getaddrinfo`-based clients (Python,
   most language runtimes); `curl` still tries `::1` first and pays a small
   extra ~0.2 s, since it ignores the OS prefix policy.
3. Set `firewall=true` (already the default here) — mirrored applies the
   Windows Hyper-V firewall to WSL, so container ports need matching inbound
   rules to be reachable from the LAN.

### Container reaching the Windows host (either mode)

Inside a container, `localhost` is the container itself — not Windows, and
not the WSL VM. To reach a service on Windows (e.g. a local Postgres), use
the WSL default-route gateway IP, which changes on every WSL boot:

```bash
export WINDOWS_HOST_IP=$(ip route show default | awk '{print $3}')
```

`provision_zshrc_config` (`wsl/lib/zsh.sh`) exports this automatically in new
shells. In `docker-compose.yml`:

```yaml
services:
  app:
    extra_hosts:
      - "windows-host:${WINDOWS_HOST_IP}"
    environment:
      DB_HOST: windows-host
```

On the Windows side, the target service needs to listen outside loopback
(e.g. Postgres: `listen_addresses='*'` plus a matching `pg_hba.conf` entry
for `172.16.0.0/12`) and a matching Windows Firewall inbound rule.

[wsl-net-apps]: https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-network-applications
