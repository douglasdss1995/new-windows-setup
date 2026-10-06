# setup-windows.ps1 runs its whole flow on load, so only the one function under
# test is extracted from it via the AST (same approach as GitClone.Tests.ps1).
BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RepoRoot 'setup-windows.ps1'), [ref]$null, [ref]$null)
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-GitConfigInclude' }, $false)
    . ([scriptblock]::Create($fn[0].Extent.Text))

    $script:Shared = Join-Path $TestDrive 'repo' 'git' '.gitconfig'
    New-Item -ItemType Directory -Path (Split-Path $script:Shared) -Force | Out-Null
    Set-Content -Path $script:Shared -Value "[pull]`n`trebase = true`n[core]`n`teditor = code --wait`n" -NoNewline
    $script:SharedOriginal = Get-Content -Path $script:Shared -Raw
}

Describe 'Set-GitConfigInclude' {
    BeforeEach {
        $script:Local = Join-Path $TestDrive "home-$([guid]::NewGuid().ToString('N'))" '.gitconfig'
        New-Item -ItemType Directory -Path (Split-Path $script:Local) -Force | Out-Null
        $script:ForwardShared = $script:Shared.Replace('\', '/')
    }

    It 'creates a real file whose first section includes the shared config' {
        $r = Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local
        $r.Status | Should -Be 'Created'
        (Get-Item $script:Local -Force).LinkType | Should -BeNullOrEmpty
        (Get-Content $script:Local)[0] | Should -Be '[include]'
        (Get-Content $script:Local -Raw) | Should -Match ([regex]::Escape("path = $($script:ForwardShared)"))
    }

    It 'uses forward slashes in the include path (Git for Windows requirement)' {
        Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local | Out-Null
        (Get-Content $script:Local -Raw) | Should -Not -Match 'path = .*\\'
    }

    It 'writes UTF-8 without a BOM' {
        Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes($script:Local)
        $bytes[0] | Should -Be ([byte][char]'[')
    }

    It 'is idempotent' {
        Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local | Out-Null
        $r = Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local
        $r.Status | Should -Be 'Unchanged'
        ([regex]::Matches((Get-Content $script:Local -Raw), '\[include\]')).Count | Should -Be 1
    }

    It 'prepends the include to an existing file, keeps its content and makes a backup' {
        Set-Content -Path $script:Local -Value "[user]`n`tname = Ada`n`temail = ada@example.com`n" -NoNewline
        $r = Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local
        $r.Status | Should -Be 'Updated'
        $r.Backup | Should -Exist
        $text = Get-Content $script:Local -Raw
        $text | Should -Match '^\[include\]'
        $text | Should -Match 'email = ada@example.com'
        $text.IndexOf('[include]') | Should -BeLessThan $text.IndexOf('[user]')
    }

    It 'lets a local value override the shared default and inherits the rest' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Set-Content -Path $script:Local -Value "[core]`n`teditor = nano`n" -NoNewline
        Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local | Out-Null
        $env:GIT_CONFIG_GLOBAL = $script:Local
        try {
            (git config --get core.editor) | Should -Be 'nano'
            (git config --get pull.rebase) | Should -Be 'true'
            git config --global user.name 'Someone'
        } finally {
            Remove-Item Env:\GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue
        }
        (Get-Content $script:Shared -Raw) | Should -Be $script:SharedOriginal
    }

    It 'replaces a legacy symlink with a real file and carries the identity over' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $legacyTarget = Join-Path $TestDrive "legacy-$([guid]::NewGuid().ToString('N')).gitconfig"
        Set-Content -Path $legacyTarget -Value "[user]`n`tname = Legacy`n`temail = legacy@example.com`n" -NoNewline
        try {
            New-Item -ItemType SymbolicLink -Path $script:Local -Target $legacyTarget -ErrorAction Stop | Out-Null
        } catch {
            Set-ItResult -Skipped -Because 'creating symlinks needs admin or Developer Mode'
            return
        }
        $r = Set-GitConfigInclude -SharedConfigPath $script:Shared -LocalConfigPath $script:Local
        $r.Status | Should -Be 'ReplacedSymlink'
        (Get-Item $script:Local -Force).LinkType | Should -BeNullOrEmpty
        (git config --file $script:Local --get user.email) | Should -Be 'legacy@example.com'
        (Get-Content $legacyTarget -Raw) | Should -Match 'Legacy'
    }
}

# The reason this whole design exists: machine/person-specific values must never
# live in the tracked shared file (they were repeatedly written there by
# `git config --global` through the old symlink).
Describe 'tracked git/.gitconfig' {
    It 'has no [<name>] section' -ForEach @(
        @{ Name = 'user' }
        @{ Name = 'credential' }
        @{ Name = 'include' }
    ) {
        $text = Get-Content (Join-Path $script:RepoRoot 'git' '.gitconfig') -Raw
        $text | Should -Not -Match "(?im)^\s*\[$Name(\s|\])"
    }
}
