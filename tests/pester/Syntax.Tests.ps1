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
