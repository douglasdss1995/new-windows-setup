# =============================================================================
# SetupConfig.ps1 - shared helpers for `make setup` and setup-wsl.ps1
#
# Dot-source this file; it only defines functions (nothing runs on load).
#
# Get-WslOptions is the single source of truth for the WSL choices: the wizard
# asks them, wsl.config.psd1 stores them, and ConvertTo-WslProvisionArgs turns
# them into the flags setup-wsl.sh understands.
# =============================================================================

function Get-WslOptions {
    # Default  = what setup-wsl.sh does when the flag is absent.
    # Flag     = the setup-wsl.sh flag emitted when the value differs from Default.
    # DependsOn = options that must be $true for this one to be asked/applied.
    @(
        [pscustomobject]@{ Key = 'Docker';                Default = $true;  Flag = '--skip-docker';    DependsOn = @();                      Question = 'Install Docker (native daemon, no Docker Desktop)?' }
        [pscustomobject]@{ Key = 'NvidiaContainerToolkit'; Default = $false; Flag = '--with-nvidia';    DependsOn = @('Docker');              Question = 'Install NVIDIA Container Toolkit (GPU in containers; needs an NVIDIA GPU)?' }
        [pscustomobject]@{ Key = 'PostgreSQL';            Default = $false; Flag = '--with-postgres';  DependsOn = @('Docker');              Question = 'Add PostgreSQL provider?' }
        [pscustomobject]@{ Key = 'PgAdmin';               Default = $false; Flag = '--with-pgadmin';   DependsOn = @('Docker', 'PostgreSQL'); Question = 'Add pgAdmin provider?' }
        [pscustomobject]@{ Key = 'Redis';                 Default = $true;  Flag = '--skip-redis';     DependsOn = @('Docker');              Question = 'Add Redis provider?' }
        [pscustomobject]@{ Key = 'Portainer';             Default = $true;  Flag = '--skip-portainer'; DependsOn = @('Docker');              Question = 'Add Portainer provider?' }
        [pscustomobject]@{ Key = 'MinIO';                 Default = $false; Flag = '--with-minio';     DependsOn = @('Docker');              Question = 'Add MinIO provider (manual start)?' }
        [pscustomobject]@{ Key = 'SeaweedFS';             Default = $false; Flag = '--with-seaweedfs'; DependsOn = @('Docker');              Question = 'Add SeaweedFS provider (manual start)?' }
        [pscustomobject]@{ Key = 'Python';                Default = $true;  Flag = '--skip-python';    DependsOn = @();                      Question = 'Install Python tooling?' }
        [pscustomobject]@{ Key = 'Node';                  Default = $true;  Flag = '--skip-node';      DependsOn = @();                      Question = 'Install Node tooling?' }
        [pscustomobject]@{ Key = 'GitKraken';             Default = $true;  Flag = '--skip-gitkraken'; DependsOn = @();                      Question = 'Install GitKraken?' }
        [pscustomobject]@{ Key = 'KeyboardLayout';        Default = $true;  Flag = '--skip-keyboard';  DependsOn = @();                      Question = 'Configure the keyboard layout (br / abnt2)?' }
    )
}

# -----------------------------------------------------------------------------
# Prompts
# -----------------------------------------------------------------------------

# y / yes / 1 -> $true ; n / no / 0 -> $false ; empty -> $Default ; anything else -> $null
function ConvertTo-YesNo {
    param(
        [AllowNull()][AllowEmptyString()][string]$Answer,
        [bool]$Default
    )
    $a = if ($null -eq $Answer) { '' } else { $Answer.Trim().ToLowerInvariant() }
    switch ($a) {
        ''      { return $Default }
        'y'     { return $true }
        'yes'   { return $true }
        '1'     { return $true }
        'n'     { return $false }
        'no'    { return $false }
        '0'     { return $false }
        default { return $null }
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][bool]$Default
    )
    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $answer = Read-Host "$Prompt [$hint]"
        $result = ConvertTo-YesNo -Answer $answer -Default $Default
        if ($null -ne $result) { return $result }
        Write-Host '  Answer y/yes/1 or n/no/0 (Enter = default).' -ForegroundColor Yellow
    }
}

# Free text; Enter keeps $Current (empty = skip).
function Read-Text {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Current = ''
    )
    $hint = if ($Current) { " [$Current]" } else { ' [Enter to skip]' }
    $answer = Read-Host "$Prompt$hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Current }
    return $answer.Trim()
}

# -----------------------------------------------------------------------------
# wsl.config.psd1 -> setup-wsl.sh flags
# -----------------------------------------------------------------------------

# Emits only the flags that differ from setup-wsl.sh's defaults, so a missing
# key (or a missing file) behaves exactly like running the script without flags.
function ConvertTo-WslProvisionArgs {
    param([Parameter(Mandatory)][hashtable]$Config)
    $flags = foreach ($opt in Get-WslOptions) {
        if (-not $Config.ContainsKey($opt.Key)) { continue }
        $value = $Config[$opt.Key]
        if ($value -isnot [bool]) {
            throw "wsl.config.psd1: '$($opt.Key)' must be `$true or `$false (got '$value')"
        }
        if ($value -ne $opt.Default) { $opt.Flag }
    }
    @($flags) -join ' '
}

function New-WslConfigContent {
    param([hashtable]$Values = @{})
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# =============================================================================')
    $lines.Add('# wsl.config.psd1 - WSL provisioning choices (read by setup-wsl.ps1)')
    $lines.Add('#')
    $lines.Add('# Generated by `make setup` (scripts/setup-wizard.ps1); safe to edit by hand.')
    $lines.Add('# true  = install / enable')
    $lines.Add('# false = skip')
    $lines.Add('# A missing key falls back to the default shown here.')
    $lines.Add('# =============================================================================')
    $lines.Add('@{')
    $width = (Get-WslOptions | ForEach-Object { $_.Key.Length } | Measure-Object -Maximum).Maximum
    foreach ($opt in Get-WslOptions) {
        $value = if ($Values.ContainsKey($opt.Key)) { [bool]$Values[$opt.Key] } else { $opt.Default }
        $literal = if ($value) { '$true ' } else { '$false' }
        $lines.Add(('    {0} = {1}  # {2}' -f $opt.Key.PadRight($width), $literal, $opt.Question))
    }
    $lines.Add('}')
    ($lines -join "`n") + "`n"
}

# -----------------------------------------------------------------------------
# Files
# -----------------------------------------------------------------------------

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# Copies each *.example config next to itself when the real file is missing.
# Never overwrites. Returns one object per file: Path + Created.
function Copy-ConfigExamples {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $targets = 'windows/windows.config.psd1', 'git/git-repos.config.psd1', 'wsl/wsl.config.psd1'
    foreach ($rel in $targets) {
        $dest = Join-Path $RepoRoot $rel
        $src  = "$dest.example"
        if (-not (Test-Path $src)) { throw "Example config not found: $src" }
        $created = $false
        if (-not (Test-Path $dest)) {
            Copy-Item -LiteralPath $src -Destination $dest
            $created = $true
        }
        [pscustomobject]@{ Path = $rel; Created = $created }
    }
}

# Rewrites Git.UserName / Git.UserEmail in windows.config.psd1 in place,
# preserving every comment and the rest of the file.
function Set-GitIdentityInConfig {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$UserName = '',
        [string]$UserEmail = ''
    )
    $text = [System.IO.File]::ReadAllText($Path)
    foreach ($pair in @(@('UserName', $UserName), @('UserEmail', $UserEmail))) {
        $key = $pair[0]
        # Single-quoted psd1 string: the only character to escape is '
        $quoted = "'" + ($pair[1] -replace "'", "''") + "'"
        $regex = [regex]::new("(?m)^(\s*$key\s*=\s*)(?:`"[^`"]*`"|'(?:[^']|'')*')")
        $evaluator = { param($m) $m.Groups[1].Value + $quoted }.GetNewClosure()
        $text = $regex.Replace($text, $evaluator, 1)
    }
    Write-Utf8NoBom -Path $Path -Content $text
}
