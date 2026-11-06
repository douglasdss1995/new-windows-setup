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
        ConvertTo-WslProvisionArgs -Config @{ Portainer = $false; GitKraken = $false } |
            Should -Be '--skip-portainer --skip-gitkraken'
    }
    It 'ignores the retired Docker/Python/Node/Valkey/Redis keys: they are mandatory now' {
        ConvertTo-WslProvisionArgs -Config @{ Docker = $false; Python = $false; Node = $false; Valkey = $false; Redis = $false } | Should -Be ''
    }
    It 'rejects non-boolean values' {
        { ConvertTo-WslProvisionArgs -Config @{ Portainer = 'no' } } | Should -Throw '*Portainer*'
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
            NvidiaContainerToolkit = 'SKIP_NVIDIA'; PostgreSQL = 'SKIP_POSTGRES'
            PgAdmin = 'SKIP_PGADMIN'; Portainer = 'SKIP_PORTAINER'; MinIO = 'SKIP_MINIO'
            SeaweedFS = 'SKIP_SEAWEEDFS'; Ollama = 'SKIP_OLLAMA'
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
            Set-Content (Join-Path $root 'wsl' 'wsl.config.psd1') '@{ Portainer = $false }'
            (Copy-ConfigExamples -RepoRoot $root).Created | Should -Be @($false, $false, $false)
            (Import-PowerShellDataFile (Join-Path $root 'wsl' 'wsl.config.psd1')).Portainer | Should -BeFalse
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
            $cfg.Terminal.OhMyPosh | Should -BeTrue
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
    It 'asks only optional tools, records the answers and saves the Git identity' {
        $queue = [System.Collections.Queue]::new()
        $asked = [System.Collections.Generic.List[string]]::new()
        # Windows: Oh My Posh = n, every other optional tool keeps its default.
        # WSL: NVIDIA = y, PostgreSQL = default (no, so pgAdmin is not asked), Portainer = 0, MinIO/SeaweedFS/Ollama = default, GitKraken = n, Keyboard = 1.
        $answers = @('n') + @('') * ((Get-WindowsOptions).Count - 1) + @('y', '', '0', '', '', '', 'n', '1', 'Jane Doe', 'jane@example.com')
        $answers | ForEach-Object { $queue.Enqueue($_) }
        Mock Read-Host { $asked.Add($Prompt); $queue.Dequeue() }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        $queue.Count | Should -Be 0
        ($asked | Where-Object { $_ -match 'Docker \(native|Python tooling|Node tooling|Chocolatey|Visual Studio Code|7-Zip' }) | Should -BeNullOrEmpty
        $cfg = Import-PowerShellDataFile (Join-Path $script:root 'wsl' 'wsl.config.psd1')
        $cfg.NvidiaContainerToolkit | Should -BeTrue
        $cfg.Portainer              | Should -BeFalse
        $cfg.GitKraken              | Should -BeFalse
        $cfg.KeyboardLayout         | Should -BeTrue
        $win = Import-PowerShellDataFile (Join-Path $script:root 'windows' 'windows.config.psd1')
        $win.Terminal.OhMyPosh | Should -BeFalse
        $win.Terminal.SetPowerShell7AsDefault | Should -BeTrue
        $win.Git.UserName | Should -Be 'Jane Doe'
        ConvertTo-WslProvisionArgs -Config $cfg | Should -Be '--with-nvidia --skip-portainer --skip-gitkraken'
    }
    It 'never asks about a mandatory tool' {
        $asked = [System.Collections.Generic.List[string]]::new()
        Mock Read-Host { $asked.Add($Prompt); '' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        $options = @(Get-WindowsOptions)
        # The first questions are exactly the optional Windows tools, in catalog order: nothing else is asked.
        $windowsAsked = @($asked | Select-Object -First $options.Count | ForEach-Object { $_ -replace ' \[[Yy]/[Nn]\]$', '' })
        $windowsAsked | Should -Be @($options.Question)
        foreach ($label in 'Docker (native', 'Python tooling', 'Node tooling', 'Valkey') { ($asked | Where-Object { $_ -like "*$label*" }) | Should -BeNullOrEmpty -Because $label }
    }
    It 'removes the keys of tools that became mandatory from an existing config, with a .bak' {
        $win = Join-Path $script:root 'windows' 'windows.config.psd1'
        $old = (Get-Content "$win.example" -Raw) -replace '(?m)^    Terminal ', "    CLI = @{`n        Ripgrep = `$false`n    }`n`n    Terminal "
        $old = $old -replace '(?m)^(    Terminal\s*= @\{\r?\n)', "`$1        Fzf = `$false`n"
        Set-Content $win $old -NoNewline
        Mock Read-Host { '' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root -UseDefaults *>$null
        $cfg = Import-PowerShellDataFile $win
        $cfg.ContainsKey('CLI') | Should -BeFalse
        $cfg.Terminal.ContainsKey('Fzf') | Should -BeFalse
        Test-Path "$win.bak" | Should -BeTrue
    }
    It 'keeps the saved answer of an optional tool as the next default' {
        $win = Join-Path $script:root 'windows' 'windows.config.psd1'
        Copy-Item "$win.example" $win
        Set-ConfigBooleans -Path $win -Values @{ 'Browsers.Opera' = $true } | Out-Null
        Mock Read-Host { '' }
        & (Join-Path $repoRoot 'scripts' 'setup-wizard.ps1') -RepoRoot $script:root *>$null
        (Import-PowerShellDataFile $win).Browsers.Opera | Should -BeTrue
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

Describe 'Set-ConfigBooleans' {
    It 'changes only the requested values and keeps comments and CRLF' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ("sb-" + [guid]::NewGuid().ToString('N') + '.psd1')
        try {
            [System.IO.File]::WriteAllText($path, "@{`r`n    Browsers = @{`r`n        Chrome = `$true   # main`r`n        Opera  = `$false`r`n    }`r`n}`r`n")
            Set-ConfigBooleans -Path $path -Values @{ 'Browsers.Chrome' = $false; 'Browsers.Nope' = $true; 'Missing.Key' = $true } | Should -Be 1
            $raw = [System.IO.File]::ReadAllText($path)
            $raw | Should -Match 'Chrome = \$false   # main'
            $raw | Should -Match 'Opera  = \$false'
            ($raw -replace "`r`n", '').Contains("`n") | Should -BeFalse
            Set-ConfigBooleans -Path $path -Values @{ 'Browsers.Chrome' = $false } | Should -Be 0
        } finally { Remove-Item $path -ErrorAction SilentlyContinue }
    }
}

Describe 'Remove-ConfigKeys' {
    BeforeEach {
        $script:file = Join-Path ([System.IO.Path]::GetTempPath()) ("rk-" + [guid]::NewGuid().ToString('N') + '.psd1')
        @'
@{
    # -------------------------------------------------------------------------
    # CLI
    # -------------------------------------------------------------------------
    CLI = @{
        Fd = $true
        Bat = $true
    }

    Browsers = @{
        Chrome = $true   # keep
        Opera  = $false
    }
}
'@ | Set-Content $script:file -NoNewline
    }
    AfterEach { Remove-Item "$($script:file)*" -ErrorAction SilentlyContinue }

    It 'removes a key, and a section left empty together with its banner' {
        $r = Remove-ConfigKeys -Path $script:file -Keys 'CLI.Fd', 'CLI.Bat', 'Browsers.Opera'
        $r | Should -Be @('CLI.Fd', 'CLI.Bat', 'Browsers.Opera')
        $cfg = Import-PowerShellDataFile $script:file
        $cfg.ContainsKey('CLI') | Should -BeFalse
        $cfg.Browsers.Keys | Should -Be @('Chrome')
        (Get-Content $script:file -Raw) | Should -Not -Match '# CLI'
        (Get-Content $script:file -Raw) | Should -Match '# keep'
        Test-Path "$($script:file).bak" | Should -BeTrue
    }
    It 'is idempotent and writes no .bak when nothing is removed' {
        Remove-ConfigKeys -Path $script:file -Keys 'Nope.Key', 'CLI.Missing' | Should -BeNullOrEmpty
        Test-Path "$($script:file).bak" | Should -BeFalse
    }
}

Describe 'windows option contract' {
    BeforeAll {
        $script:example = Import-PowerShellDataFile (Join-Path $repoRoot 'windows' 'windows.config.psd1.example')
        $script:optionRefs = (Get-WindowsOptions) | ForEach-Object { "$($_.Section).$($_.Key)" }
    }
    It 'every optional tool is a boolean in the example with the catalog default' {
        $bad = foreach ($o in Get-WindowsOptions) {
            $sec = $script:example[$o.Section]
            if ($null -eq $sec -or -not $sec.ContainsKey($o.Key)) { "$($o.Section).$($o.Key) missing"; continue }
            if ($sec[$o.Key] -isnot [bool] -or $sec[$o.Key] -ne $o.Default) { "$($o.Section).$($o.Key) default differs" }
        }
        $bad | Should -BeNullOrEmpty
    }
    It 'every boolean in the example is an optional tool in the catalog' {
        $bad = foreach ($section in $script:example.Keys) {
            if ($section -eq 'Git') { continue }
            foreach ($k in $script:example[$section].Keys) {
                if ($script:example[$section][$k] -is [bool] -and "$section.$k" -notin $script:optionRefs) { "$section.$k" }
            }
        }
        $bad | Should -BeNullOrEmpty
    }
    It 'no retired (mandatory) key is in the example, and none is also an option' {
        $retired = Get-WindowsRetiredKeys
        foreach ($ref in $retired) {
            $section, $key = $ref -split '\.', 2
            if ($script:example.ContainsKey($section)) { $script:example[$section].ContainsKey($key) | Should -BeFalse -Because $ref }
            $ref | Should -Not -BeIn $script:optionRefs
        }
    }
    It 'setup-windows.ps1 reads only optional tools from $cfg and never a retired key' {
        $script = Get-Content (Join-Path $repoRoot 'setup-windows.ps1') -Raw
        $read = [regex]::Matches($script, '\$cfg\.([A-Za-z0-9]+)\.([A-Za-z0-9]+)') | ForEach-Object { "$($_.Groups[1].Value).$($_.Groups[2].Value)" } | Sort-Object -Unique
        $allowed = @($script:optionRefs) + 'Git.UserName', 'Git.UserEmail', 'Terminal.OhMyPoshTheme'
        ($read | Where-Object { $_ -notin $allowed }) | Should -BeNullOrEmpty
        ($read | Where-Object { $_ -in (Get-WindowsRetiredKeys) }) | Should -BeNullOrEmpty
    }
    It 'the Windows PostgreSQL password in the installer is the one the wizard tells the user' {
        $script = Get-Content (Join-Path $repoRoot 'setup-windows.ps1') -Raw
        $m = [regex]::Match($script, '\$PostgresPassword = "([^"]+)"')
        $m.Success | Should -BeTrue
        $pw = $m.Groups[1].Value
        $script | Should -Match '--superpassword \$PostgresPassword'
        ((Get-WindowsOptions) | Where-Object Key -eq 'PostgreSQL18').Note | Should -Match ([regex]::Escape($pw))
    }
    It 'every optional tool except the VS Code extensions is read by setup-windows.ps1' {
        $script = Get-Content (Join-Path $repoRoot 'setup-windows.ps1') -Raw
        $unused = foreach ($o in Get-WindowsOptions) {
            if ($o.Section -eq 'VSCodeExtensions') { if ($script -notmatch "\`$ext\.$($o.Key)\b") { "$($o.Section).$($o.Key)" }; continue }
            if ($script -notmatch [regex]::Escape("`$cfg.$($o.Section).$($o.Key)")) { "$($o.Section).$($o.Key)" }
        }
        $unused | Should -BeNullOrEmpty
    }
}
