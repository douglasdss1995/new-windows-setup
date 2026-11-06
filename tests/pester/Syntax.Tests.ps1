# Every script must at least parse — catches typos before a 20-minute setup run does.
BeforeDiscovery {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $scripts = Get-ChildItem -Path $repoRoot -Recurse -Include *.ps1, *.psd1, *.example -File |
        Where-Object { $_.FullName -notmatch '[\\/](\.git|docs)[\\/]' -and $_.Name -notmatch '\.Tests\.ps1$' } |
        ForEach-Object { @{ Name = $_.FullName.Substring($repoRoot.Length + 1); Path = $_.FullName } }
}

Describe 'PowerShell syntax' {
    It '<Name> parses without errors' -ForEach $scripts {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}

# Windows PowerShell 5.1 reads a script without a BOM as ANSI: an em dash becomes 3 odd
# characters (one of them a smart quote) and breaks the parse. The scripts users launch
# with `powershell` / `pwsh` from the repo root must therefore be pure ASCII (or have a BOM).
Describe 'entry scripts are safe for Windows PowerShell 5.1' {
    It '<Name> is ASCII-only or has a UTF-8 BOM' -ForEach @(
        Get-ChildItem -Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path -Filter *.ps1 -File |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
    ) {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $nonAscii = @($bytes | Where-Object { $_ -gt 127 }).Count
        ($hasBom -or $nonAscii -eq 0) | Should -BeTrue -Because "$Name has $nonAscii non-ASCII bytes and no BOM"
    }
    It 'setup-wsl.ps1 refuses to run on PowerShell 5.1 with a clear message' {
        $script = Get-Content (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path 'setup-wsl.ps1') -Raw
        $script | Should -Match "PSVersion -lt \[version\]'7\.0'"
    }
    It 'no doc or script tells the user to run setup-wsl.ps1 with the powershell (5.1) command' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $hits = Get-ChildItem -Path $root -Recurse -Include *.md, *.ps1 -File |
            Where-Object { $_.FullName -notmatch '[\/](\.git|tests)[\/]' } |
            Select-String -Pattern 'powershell[^
]*setup-wsl\.ps1'
        $hits | Should -BeNullOrEmpty
    }
}
