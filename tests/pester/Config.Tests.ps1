# The example config is the contract: every flag setup-windows.ps1 reads must exist
# in it, otherwise a fresh copy of the example silently skips that tool.
BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $example  = Import-PowerShellDataFile (Join-Path $repoRoot 'windows' 'windows.config.psd1.example')
    $script   = Get-Content (Join-Path $repoRoot 'setup-windows.ps1') -Raw
    $refs = [regex]::Matches($script, '\$cfg\.([A-Za-z0-9]+)(?:\.([A-Za-z0-9]+))?') |
        ForEach-Object { "$($_.Groups[1].Value).$($_.Groups[2].Value)" } |
        Sort-Object -Unique
}

Describe 'windows.config.psd1.example' {
    It 'is valid PowerShell data' {
        $example | Should -BeOfType [hashtable]
    }
    It 'defines every $cfg key that setup-windows.ps1 reads' {
        $missing = foreach ($ref in $refs) {
            $section, $key = $ref -split '\.', 2
            if (-not $example.ContainsKey($section)) { $section; continue }
            if ($key -and ($example[$section] -is [hashtable]) -and -not $example[$section].ContainsKey($key)) { $ref }
        }
        $missing | Should -BeNullOrEmpty
    }
    It 'uses booleans for tool flags' {
        $bad = foreach ($section in 'Editors', 'CLI', 'Runtimes', 'Browsers') {
            foreach ($k in $example[$section].Keys) {
                if ($example[$section][$k] -isnot [bool]) { "$section.$k" }
            }
        }
        $bad | Should -BeNullOrEmpty
    }
}

Describe 'git-repos.config.psd1.example' {
    It 'is valid PowerShell data with the keys git-clone.ps1 needs' {
        $cfg = Import-PowerShellDataFile (Join-Path $repoRoot 'git' 'git-repos.config.psd1.example')
        $cfg.Keys | Should -Contain 'CloneBaseDir'
        $cfg.Keys | Should -Contain 'Providers'
        $cfg.Keys | Should -Contain 'Repositories'
    }
}
