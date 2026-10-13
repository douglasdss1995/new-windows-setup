# Covers scripts/SetupConfig.ps1 and scripts/setup-wizard.ps1 (`make setup`).
BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    . (Join-Path $repoRoot 'scripts' 'SetupConfig.ps1')

    # A throwaway repo tree holding only the example configs, so the wizard never touches the real ones.
    function New-FakeRepo {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("nws-" + [guid]::NewGuid().ToString('N'))
        foreach ($dir in 'windows', 'git', 'wsl') { New-Item -ItemType Directory -Path (Join-Path $root $dir) | Out-Null }
        Copy-Item (Join-Path $repoRoot 'windows' 'windows.config.psd1.example') (Join-Path $root 'windows')
        Copy-Item (Join-Path $repoRoot 'git' 'git-repos.config.psd1.example')   (Join-Path $root 'git')
        Copy-Item (Join-Path $repoRoot 'wsl' 'wsl.config.psd1.example')         (Join-Path $root 'wsl')
        $root
    }
}

Describe 'ConvertTo-YesNo' {
    It 'maps <answer> to <expected> (default <default>)' -ForEach @(
        @{ answer = 'y';     default = $false; expected = $true }
        @{ answer = 'Y';     default = $false; expected = $true }
        @{ answer = 'yes';   default = $false; expected = $true }
        @{ answer = 'YES';   default = $false; expected = $true }
        @{ answer = '1';     default = $false; expected = $true }
        @{ answer = 'n';     default = $true;  expected = $false }
        @{ answer = 'No';    default = $true;  expected = $false }
        @{ answer = '0';     default = $true;  expected = $false }
        @{ answer = '';      default = $true;  expected = $true }
        @{ answer = '';      default = $false; expected = $false }
        @{ answer = '   ';   default = $true;  expected = $true }
        @{ answer = $null;   default = $false; expected = $false }
    ) {
        ConvertTo-YesNo -Answer $answer -Default $default | Should -Be $expected
    }
    It 'returns $null for an unrecognised answer' {
        ConvertTo-YesNo -Answer 'maybe' -Default $true | Should -BeNullOrEmpty
        ConvertTo-YesNo -Answer '2'     -Default $true | Should -BeNullOrEmpty
    }
}

Describe 'Read-YesNo' {
    It 'asks again after an invalid answer' {
        $queue = [System.Collections.Queue]::new(@('banana', '1'))
        Mock Read-Host { $queue.Dequeue() }
        Mock Write-Host {}
        Read-YesNo -Prompt 'Install?' -Default $false | Should -BeTrue
        Should -Invoke Read-Host -Times 2 -Exactly
    }
    It 'returns the default when only Enter is pressed' {
        Mock Read-Host { '' }
        Read-YesNo -Prompt 'Install?' -Default $true  | Should -BeTrue
        Read-YesNo -Prompt 'Install?' -Default $false | Should -BeFalse
    }
    It 'shows the default as a capital letter' {
        Mock Read-Host { '' } -ParameterFilter { $Prompt -eq 'Install? [Y/n]' }
        Read-YesNo -Prompt 'Install?' -Default $true | Should -BeTrue
        Should -Invoke Read-Host -ParameterFilter { $Prompt -eq 'Install? [Y/n]' } -Times 1 -Exactly
    }
}

Describe 'ConvertTo-WslProvisionArgs' {
    It 'emits nothing for an empty config or for default values' {
        ConvertTo-WslProvisionArgs -Config @{} | Should -Be ''
        $defaults = @{}
        foreach ($o in Get-WslOptions) { $defaults[$o.Key] = $o.Default }
        ConvertTo-WslProvisionArgs -Config $defaults | Should -Be ''
    }
    It 'emits --with-nvidia only when opted in' {
        ConvertTo-WslProvisionArgs -Config @{ NvidiaContainerToolkit = $true }  | Should -Be '--with-nvidia'
        ConvertTo-WslProvisionArgs -Config @{ NvidiaContainerToolkit = $false } | Should -Be ''
    }
    It 'emits --skip-* for tools turned off' {
        ConvertTo-WslProvisionArgs -Config @{ Docker = $false; Node = $false } |
            Should -Be '--skip-docker --skip-node'
    }
    It 'rejects non-boolean values' {
        { ConvertTo-WslProvisionArgs -Config @{ Docker = 'no' } } | Should -Throw '*Docker*'
    }
}

Describe 'wsl option contract' {
    It 'wsl.config.psd1.example is exactly what New-WslConfigContent generates' {
        $path = Join-Path $repoRoot 'wsl' 'wsl.config.psd1.example'
        ([System.IO.File]::ReadAllText($path)) | Should -BeExactly (New-WslConfigContent)
    }
    It 'wsl.config.psd1.example is valid PowerShell data covering every option' {
        $cfg = Import-PowerShellDataFile (Join-Path $repoRoot 'wsl' 'wsl.config.psd1.example')
        $keys = (Get-WslOptions).Key
        $cfg.Keys | Sort-Object | Should -Be ($keys | Sort-Object)
    }
    It 'every flag is handled by setup-wsl.sh' {
        $script = Get-Content (Join-Path $repoRoot 'wsl' 'setup-wsl.sh') -Raw
        $unknown = foreach ($o in Get-WslOptions) {
            if ($script -notmatch [regex]::Escape("$($o.Flag))")) { $o.Flag }
        }
        $unknown | Should -BeNullOrEmpty
    }
    It 'defaults match the SKIP_* defaults in setup-wsl.sh' {
        $script = Get-Content (Join-Path $repoRoot 'wsl' 'setup-wsl.sh') -Raw
        $vars = @{
            Docker = 'SKIP_DOCKER'; NvidiaContainerToolkit = 'SKIP_NVIDIA'; PostgreSQL = 'SKIP_POSTGRES'
            PgAdmin = 'SKIP_PGADMIN'; Redis = 'SKIP_REDIS'; Portainer = 'SKIP_PORTAINER'; MinIO = 'SKIP_MINIO'
            SeaweedFS = 'SKIP_SEAWEEDFS'; Python = 'SKIP_PYTHON'; Node = 'SKIP_NODE'
            GitKraken = 'SKIP_GITKRAKEN'; KeyboardLayout = 'SKIP_KEYBOARD'
        }
        $bad = foreach ($o in Get-WslOptions) {
            $skipDefault = [regex]::Match($script, "(?m)^$($vars[$o.Key])=(true|false)").Groups[1].Value
            $installByDefault = $skipDefault -eq 'false'
            if ($installByDefault -ne $o.Default) { $o.Key }
        }
        $bad | Should -BeNullOrEmpty
    }
}

Describe 'Copy-ConfigExamples' {
    It 'creates missing configs and never overwrites existing ones' {
        $root = New-FakeRepo
        try {
            (Copy-ConfigExamples -RepoRoot $root).Created | Should -Be @($true, $true, $true)
            Set-Content (Join-Path $root 'wsl' 'wsl.config.psd1') '@{ Docker = $false }'
            (Copy-ConfigExamples -RepoRoot $root).Created | Should -Be @($false, $false, $false)
            (Import-PowerShellDataFile (Join-Path $root 'wsl' 'wsl.config.psd1')).Docker | Should -BeFalse
        } finally { Remove-Item $root -Recurse -Force }
    }
}

Describe 'Set-GitIdentityInConfig' {
    It 'rewrites only the identity and keeps the file valid' {
        $root = New-FakeRepo
        try {
            $path = Join-Path $root 'windows' 'windows.config.psd1'
            Copy-Item "$path.example" $path
            Set-GitIdentityInConfig -Path $path -UserName "Jane O'Brien" -UserEmail 'jane@example.com'
            $cfg = Import-PowerShellDataFile $path
            $cfg.Git.UserName  | Should -Be "Jane O'Brien"
            $cfg.Git.UserEmail | Should -Be 'jane@example.com'
            $cfg.PackageManagers.Chocolatey | Should -BeTrue
            (Get-Content $path -Raw) | Should -Match 'Git configuration'
        } finally { Remove-Item $root -Recurse -Force }
    }
}

Describe 'setup-wizard.ps1' {
    BeforeEach { $script:root = New-FakeRepo }
    AfterEach  { Remove-Item $script:root -Recurse -Force }

    It '-ConfigOnly copies the configs and asks nothing' {
        Mock Read-Host { throw 'must not prompt' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root -ConfigOnly *>$null
        Test-Path (Join-Path $script:root 'wsl' 'wsl.config.psd1') | Should -BeTrue
        Test-Path (Join-Path $script:root 'windows' 'windows.config.psd1') | Should -BeTrue
        Test-Path (Join-Path $script:root 'git' 'git-repos.config.psd1') | Should -BeTrue
    }
    It '-UseDefaults writes the defaults without prompting' {
        Mock Read-Host { throw 'must not prompt' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root -UseDefaults *>$null
        $cfg = Import-PowerShellDataFile (Join-Path $script:root 'wsl' 'wsl.config.psd1')
        foreach ($o in Get-WslOptions) { $cfg[$o.Key] | Should -Be $o.Default }
    }
    It 'Enter on every question keeps the defaults' {
        Mock Read-Host { '' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        $cfg = Import-PowerShellDataFile (Join-Path $script:root 'wsl' 'wsl.config.psd1')
        foreach ($o in Get-WslOptions) { $cfg[$o.Key] | Should -Be $o.Default }
    }
    It 'records answers, skips dependants of Docker=no, and saves the Git identity' {
        $queue = [System.Collections.Queue]::new()
        # Docker=n -> every Docker-dependent question is skipped; remaining: Python, Node, GitKraken, Keyboard, name, email
        'n', '0', 'no', '', '1', 'Jane Doe', 'jane@example.com' | ForEach-Object { $queue.Enqueue($_) }
        Mock Read-Host { $queue.Dequeue() }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        $cfg = Import-PowerShellDataFile (Join-Path $script:root 'wsl' 'wsl.config.psd1')
        $cfg.Docker                 | Should -BeFalse
        $cfg.NvidiaContainerToolkit | Should -BeFalse
        $cfg.Redis                  | Should -BeFalse
        $cfg.Python                 | Should -BeFalse
        $cfg.Node                   | Should -BeFalse
        $cfg.GitKraken              | Should -BeTrue
        $cfg.KeyboardLayout         | Should -BeTrue
        $win = Import-PowerShellDataFile (Join-Path $script:root 'windows' 'windows.config.psd1')
        $win.Git.UserName | Should -Be 'Jane Doe'
        ConvertTo-WslProvisionArgs -Config $cfg | Should -Match '--skip-docker'
    }
    It 'uses saved values as the next defaults' {
        Set-Content (Join-Path $script:root 'wsl' 'wsl.config.psd1') '@{ NvidiaContainerToolkit = $true }'
        Mock Read-Host { '' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        (Import-PowerShellDataFile (Join-Path $script:root 'wsl' 'wsl.config.psd1')).NvidiaContainerToolkit | Should -BeTrue
    }
}

Describe 'Sync-ConfigKeys' {
    BeforeEach {
        $script:dir = Join-Path ([System.IO.Path]::GetTempPath()) ("sync-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:dir | Out-Null
        $script:example = Join-Path $script:dir 'example.psd1'
        $script:config  = Join-Path $script:dir 'config.psd1'
        @'
@{
    # Editors
    Editors = @{
        Code    = $true    # main editor
        Vim     = $false
        Cursor  = $true    # new in the example
    }

    # -------------------------------------------------------------------------
    # Browsers
    # -------------------------------------------------------------------------
    Browsers = @{
        Chrome = $true
    }
}
'@ | Set-Content $script:example -NoNewline
    }
    AfterEach { Remove-Item $script:dir -Recurse -Force }

    It 'adds a missing key after its predecessor, keeping the example comment and every local value' {
        @'
@{
    # my own comment
    Editors = @{
        Code = $false   # I changed this
        Vim  = $true
    }

    Browsers = @{
        Chrome = $false
    }
}
'@ | Set-Content $script:config -NoNewline
        $r = Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config
        $r.Added | Should -Be @('Editors.Cursor')
        $text = Get-Content $script:config -Raw
        $text | Should -Match 'Cursor  = \$true    # new in the example'
        $text | Should -Match '# my own comment'
        $cfg = Import-PowerShellDataFile $script:config
        $cfg.Editors.Code | Should -BeFalse
        $cfg.Editors.Vim  | Should -BeTrue
        $cfg.Editors.Cursor | Should -BeTrue
        $cfg.Browsers.Chrome | Should -BeFalse
    }
    It 'keeps the example order: the new key lands right after the last known predecessor' {
        "@{`n    Editors = @{`n        Code = `$true`n        Vim  = `$true`n    }`n    Browsers = @{`n        Chrome = `$true`n    }`n}`n" | Set-Content $script:config -NoNewline
        Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config | Out-Null
        $lines = Get-Content $script:config
        $vim = [array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'Vim' })
        $lines[$vim + 1] | Should -Match 'Cursor'
    }
    It 'adds a whole missing section with its banner comment' {
        "@{`n    Editors = @{`n        Code = `$true`n        Vim = `$false`n        Cursor = `$true`n    }`n}`n" | Set-Content $script:config -NoNewline
        $r = Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config
        $r.Added | Should -Be @('Browsers.Chrome')
        (Get-Content $script:config -Raw) | Should -Match '# Browsers'
        (Import-PowerShellDataFile $script:config).Browsers.Chrome | Should -BeTrue
    }
    It 'is idempotent and writes a .bak only when something changed' {
        "@{`n    Editors = @{`n        Code = `$true`n    }`n    Browsers = @{`n        Chrome = `$true`n    }`n}`n" | Set-Content $script:config -NoNewline
        (Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config).Added.Count | Should -Be 2
        Test-Path "$($script:config).bak" | Should -BeTrue
        Remove-Item "$($script:config).bak"
        $before = Get-Content $script:config -Raw
        (Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config).Added | Should -BeNullOrEmpty
        Get-Content $script:config -Raw | Should -BeExactly $before
        Test-Path "$($script:config).bak" | Should -BeFalse
    }
    It 'reports keys the example no longer has and never deletes them' {
        "@{`n    Editors = @{`n        Code = `$true`n        Vim = `$false`n        Cursor = `$true`n        OldEditor = `$true`n    }`n    Browsers = @{`n        Chrome = `$true`n    }`n}`n" | Set-Content $script:config -NoNewline
        $r = Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config
        $r.Unknown | Should -Be @('Editors.OldEditor')
        (Import-PowerShellDataFile $script:config).Editors.OldEditor | Should -BeTrue
    }
    It 'preserves CRLF line endings' {
        [System.IO.File]::WriteAllText($script:config, "@{`r`n    Editors = @{`r`n        Code = `$true`r`n    }`r`n    Browsers = @{`r`n        Chrome = `$true`r`n    }`r`n}`r`n")
        Sync-ConfigKeys -ExamplePath $script:example -ConfigPath $script:config | Out-Null
        $raw = [System.IO.File]::ReadAllText($script:config)
        ($raw -replace "`r`n", '').Contains("`n") | Should -BeFalse
    }
    It 'brings the previous real config (PostgreSQL16, no Opera/RemoteWSL) in line with the real example' {
        # Same shape as the file that sat unsynced on a real machine.
        $oldConfig = (Get-Content (Join-Path $repoRoot 'windows' 'windows.config.psd1.example') -Raw) `
            -replace '(?m)^\s*Opera\s*=.*\r?\n', '' `
            -replace '(?m)^\s*RemoteWSL\s*=.*\r?\n', '' `
            -replace 'PostgreSQL18', 'PostgreSQL16'
        Set-Content $script:config $oldConfig -NoNewline
        $realExample = Join-Path $repoRoot 'windows' 'windows.config.psd1.example'
        $r = Sync-ConfigKeys -ExamplePath $realExample -ConfigPath $script:config
        $r.Added | Should -Contain 'Database.PostgreSQL18'
        $r.Added | Should -Contain 'Browsers.Opera'
        $r.Added | Should -Contain 'VSCodeExtensions.RemoteWSL'
        $r.Unknown | Should -Be @('Database.PostgreSQL16')
        $r.Manual | Should -BeNullOrEmpty
        $a = Import-PowerShellDataFile $script:config
        $e = Import-PowerShellDataFile $realExample
        foreach ($s in $e.Keys) { foreach ($k in $e[$s].Keys) { $a[$s].ContainsKey($k) | Should -BeTrue -Because "$s.$k" } }
    }
}

Describe 'setup-wizard.ps1 config sync' {
    It 'adds new example keys to an existing windows.config.psd1' {
        $root = New-FakeRepo
        try {
            $win = Join-Path $root 'windows' 'windows.config.psd1'
            (Get-Content "$win.example" -Raw) -replace '(?m)^\s*Opera\s*=.*\r?\n', '' | Set-Content $win -NoNewline
            (Import-PowerShellDataFile $win).Browsers.ContainsKey('Opera') | Should -BeFalse
            & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $root -ConfigOnly *>$null
            (Import-PowerShellDataFile $win).Browsers.ContainsKey('Opera') | Should -BeTrue
        } finally { Remove-Item $root -Recurse -Force }
    }
}
