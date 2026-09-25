# git-clone.ps1 runs its main flow on load, so we extract only its function
# definitions via the AST and dot-source those — no refactor of the script needed.
BeforeAll {
    $scriptPath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'git-clone.ps1')
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
    foreach ($f in $functions) { . ([scriptblock]::Create($f.Extent.Text)) }
}

Describe 'Get-RepoName' {
    It 'strips the .git suffix' {
        Get-RepoName 'https://github.com/acme/api.git' | Should -Be 'api'
    }
    It 'handles URLs without .git' {
        Get-RepoName 'https://github.com/acme/api' | Should -Be 'api'
    }
    It 'ignores a trailing slash' {
        Get-RepoName 'https://gitlab.com/acme/web/' | Should -Be 'web'
    }
}

Describe 'Get-AuthenticatedUrl' {
    It 'embeds the token as oauth2 credentials' {
        Get-AuthenticatedUrl 'https://gitlab.com/acme/api.git' 'tok123' |
            Should -Be 'https://oauth2:tok123@gitlab.com/acme/api.git'
    }
}

Describe 'Resolve-Provider' {
    It 'returns the provider matching the key' {
        $providers = @{ github = @{ Host = 'github.com' } }
        (Resolve-Provider $providers 'https://github.com/a/b.git' 'github').Host | Should -Be 'github.com'
    }
    It 'throws and lists available providers for an unknown key' {
        { Resolve-Provider @{ github = @{} } 'https://x/y.git' 'nope' } | Should -Throw '*Available: github*'
    }
}

Describe 'Get-SshEnv' {
    It 'throws when the key file is missing' {
        { Get-SshEnv (Join-Path $TestDrive 'missing') } | Should -Throw '*SSH key not found*'
    }
    It 'builds a GIT_SSH_COMMAND with forward slashes' {
        $key = Join-Path $TestDrive 'id_ed25519'
        Set-Content -Path $key -Value 'x'
        $cmd = Get-SshEnv $key
        $cmd | Should -Match '^ssh -i "'
        $cmd | Should -Not -Match '\\'
        $cmd | Should -Match 'StrictHostKeyChecking=accept-new'
    }
}
