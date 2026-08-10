# .wslconfig

Global WSL configuration, copied to `%USERPROFILE%\.wslconfig`.

Optimized for **32 GB RAM / 16 cores**. Adjust for your machine:

```ini
[wsl2]
memory=16GB        # 50% of total RAM recommended
processors=8       # half of logical cores
swap=4GB
networkingMode=mirrored   # shared localhost Windows <-> WSL
autoMemoryReclaim=gradual # returns RAM to Windows when idle
```
