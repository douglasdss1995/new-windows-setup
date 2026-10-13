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
    # Default   = what setup-wsl.sh does when the flag is absent.
    # Flag      = the setup-wsl.sh flag emitted when the value differs from Default.
    # DependsOn = options that must be $true for this one to be asked/applied.
    # Help      = what the option installs and what it needs. "Requires" and
    #             "Skipped when turned off" lines are derived by Get-WslOptionHelp.
    @(
        [pscustomobject]@{
            Key = 'Docker'; Default = $true; Flag = '--skip-docker'; DependsOn = @()
            Question = 'Install Docker (native daemon, no Docker Desktop)?'
            Help = @('Installs the Docker engine inside WSL and enables it through systemd.',
                     'Needs systemd=true in /etc/wsl.conf (already set by this repo).')
        }
        [pscustomobject]@{
            Key = 'NvidiaContainerToolkit'; Default = $false; Flag = '--with-nvidia'; DependsOn = @('Docker')
            Question = 'Install NVIDIA Container Toolkit (GPU in containers)?'
            Help = @('Lets containers use the GPU (docker run --gpus all).',
                     'Needs an NVIDIA GPU and the regular NVIDIA driver installed on WINDOWS (with WSL support).',
                     'Never install a Linux NVIDIA driver inside WSL; nvidia-smi must already work there.',
                     'If no GPU is visible at install time the step is skipped with a warning.')
        }
        [pscustomobject]@{
            Key = 'PostgreSQL'; Default = $false; Flag = '--with-postgres'; DependsOn = @('Docker')
            Question = 'Add PostgreSQL provider?'
            Help = @('Container on localhost:5433, started with the other providers.')
        }
        [pscustomobject]@{
            Key = 'PgAdmin'; Default = $false; Flag = '--with-pgadmin'; DependsOn = @('Docker', 'PostgreSQL')
            Question = 'Add pgAdmin provider?'
            Help = @('Web UI for PostgreSQL on http://localhost:5050.')
        }
        [pscustomobject]@{
            Key = 'Redis'; Default = $true; Flag = '--skip-redis'; DependsOn = @('Docker')
            Question = 'Add Redis provider?'
            Help = @('Container on localhost:6379.')
        }
        [pscustomobject]@{
            Key = 'Portainer'; Default = $true; Flag = '--skip-portainer'; DependsOn = @('Docker')
            Question = 'Add Portainer provider?'
            Help = @('Docker web UI on http://localhost:8001.')
        }
        [pscustomobject]@{
            Key = 'MinIO'; Default = $false; Flag = '--with-minio'; DependsOn = @('Docker')
            Question = 'Add MinIO provider (manual start)?'
            Help = @('S3-compatible storage on :9000 (console :9001); discontinued upstream.',
                     'Never starts with the machine: docker compose --profile minio up -d minio.')
        }
        [pscustomobject]@{
            Key = 'SeaweedFS'; Default = $false; Flag = '--with-seaweedfs'; DependsOn = @('Docker')
            Question = 'Add SeaweedFS provider (manual start)?'
            Help = @('S3-compatible storage on :8333 (filer :8888, master :9333); MinIO alternative.',
                     'Never starts with the machine: docker compose --profile seaweedfs up -d seaweedfs.')
        }
        [pscustomobject]@{
            Key = 'Python'; Default = $true; Flag = '--skip-python'; DependsOn = @()
            Question = 'Install Python tooling?'
            Help = @('Python (latest) via mise, plus uv, poetry, black, ruff, mypy, pytest, ipython, httpie, pre-commit.')
        }
        [pscustomobject]@{
            Key = 'Node'; Default = $true; Flag = '--skip-node'; DependsOn = @()
            Question = 'Install Node tooling?'
            Help = @('Node LTS via mise, plus pnpm, Angular CLI (Linux build), TypeScript, ESLint, Prettier.')
        }
        [pscustomobject]@{
            Key = 'GitKraken'; Default = $true; Flag = '--skip-gitkraken'; DependsOn = @()
            Question = 'Install GitKraken?'
            Help = @('Linux GitKraken for repos on the WSL filesystem (~150 MB download).',
                     'Needs WSLg (Windows 11, or Windows 10 with WSLg) to show its window.',
                     'The Windows GitKraken is installed separately by setup-windows.ps1.')
        }
        [pscustomobject]@{
            Key = 'KeyboardLayout'; Default = $true; Flag = '--skip-keyboard'; DependsOn = @()
            Question = 'Configure the keyboard layout (br / abnt2)?'
            Help = @('Fixes accents in GUI apps run through WSLg (GitKraken, ...), which ignore the Windows layout.',
                     'Turn off if you do not use a Brazilian ABNT2 keyboard.')
        }
    )
}

# Explanatory lines for one option: its Help plus what it requires and what is
# skipped when it is turned off (both derived from DependsOn, so they cannot drift).
function Get-WslOptionHelp {
    param([Parameter(Mandatory)][pscustomobject]$Option)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($h in $Option.Help) { $lines.Add($h) }
    if ($Option.DependsOn.Count -gt 0) {
        $lines.Add("Requires: $($Option.DependsOn -join ' + ') set to yes (not asked, and forced to no, otherwise).")
    }
    $dependents = @(Get-WslOptions | Where-Object { $_.DependsOn -contains $Option.Key } | ForEach-Object Key)
    if ($dependents.Count -gt 0) {
        $lines.Add("If you answer no, these are skipped too: $($dependents -join ', ').")
    }
    $lines
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
        $lines.Add('')
        $lines.Add("    # $($opt.Question)")
        foreach ($h in Get-WslOptionHelp -Option $opt) { $lines.Add("    #   $h") }
        $lines.Add(('    {0} = {1}' -f $opt.Key.PadRight($width), $literal.TrimEnd()))
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

# -----------------------------------------------------------------------------
# Keeping a local config in step with its .example
# -----------------------------------------------------------------------------

# Line-based map of a psd1 shaped like windows.config.psd1: a root @{ } holding
# one level of `Section = @{ ... }` blocks with `Key = value` lines.
# Returns Section -> @{ Start; End; Keys = Key -> line index }.
function Get-PsdSectionMap {
    param([Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines)
    $sections = [ordered]@{}
    $current = $null
    $depth = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].TrimStart().StartsWith('#')) { continue }
        $code = ($Lines[$i] -replace '\s+#.*$', '')
        $delta = ([regex]::Matches($code, '@\{')).Count - ([regex]::Matches($code, '\}')).Count

        if ($depth -eq 1 -and $code -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*@\{') {
            $current = @{ Name = $Matches[1]; Start = $i; End = -1; Keys = [ordered]@{}; Inline = ($delta -eq 0) }
            $sections[$current.Name] = $current
        } elseif ($depth -eq 2 -and $current -and $code -match '^\s*([A-Za-z][A-Za-z0-9]*)\s*=') {
            $current.Keys[$Matches[1]] = $i
        }

        $depth += $delta
        if ($current -and $depth -eq 1 -and $current.End -lt 0) {
            $current.End = $i
            $current = $null
        }
    }
    $sections
}

# Adds to $ConfigPath the keys (and whole sections) that exist in $ExamplePath
# but not yet in the config, using the example's value and trailing comment, and
# leaves everything else (your values, comments, order) untouched. Never removes
# anything: keys the example no longer knows are only reported (usually a rename).
# Idempotent. Writes a .bak next to the config only when it changes something.
function Sync-ConfigKeys {
    param(
        [Parameter(Mandatory)][string]$ExamplePath,
        [Parameter(Mandatory)][string]$ConfigPath
    )
    $added = [System.Collections.Generic.List[string]]::new()
    $unknown = [System.Collections.Generic.List[string]]::new()
    $manual = [System.Collections.Generic.List[string]]::new()

    $exampleRaw = [System.IO.File]::ReadAllText($ExamplePath)
    $configRaw  = [System.IO.File]::ReadAllText($ConfigPath)
    $nl = if ($configRaw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $ex = [System.Collections.Generic.List[string]]::new([string[]]($exampleRaw -split "`r?`n"))
    $cf = [System.Collections.Generic.List[string]]::new([string[]]($configRaw -split "`r?`n"))

    $exMap = Get-PsdSectionMap -Lines $ex.ToArray()
    foreach ($name in $exMap.Keys) {
        $exSec = $exMap[$name]
        $cfMap = Get-PsdSectionMap -Lines $cf.ToArray()

        if (-not $cfMap.Contains($name)) {
            # Whole section missing: copy its banner comments + block before the root's closing brace.
            $from = $exSec.Start
            while ($from -gt 0 -and $ex[$from - 1].TrimStart().StartsWith('#')) { $from-- }
            $block = @('') + $ex.GetRange($from, $exSec.End - $from + 1)
            $rootEnd = -1
            for ($i = $cf.Count - 1; $i -ge 0; $i--) { if ($cf[$i].Trim() -eq '}') { $rootEnd = $i; break } }
            if ($rootEnd -lt 0) { $manual.Add($name); continue }
            $cf.InsertRange($rootEnd, [string[]]$block)
            foreach ($k in $exSec.Keys.Keys) { $added.Add("$name.$k") }
            continue
        }

        $cfSec = $cfMap[$name]
        if ($cfSec.Inline -or $exSec.Inline) { $manual.Add($name); continue }

        $previous = $null
        foreach ($key in $exSec.Keys.Keys) {
            $cfSec = (Get-PsdSectionMap -Lines $cf.ToArray())[$name]
            if ($cfSec.Keys.Contains($key)) { $previous = $key; continue }

            $line = $ex[$exSec.Keys[$key]]
            $code = $line -replace '\s+#.*$', ''
            if (([regex]::Matches($code, '@\{|@\(|\(')).Count -ne ([regex]::Matches($code, '\)|\}')).Count) {
                $manual.Add("$name.$key")   # multi-line value: not safe to copy line by line
                continue
            }
            $at = if ($previous) { $cfSec.Keys[$previous] + 1 } else { $cfSec.Start + 1 }
            $cf.Insert($at, $line)
            $added.Add("$name.$key")
            $previous = $key
        }
    }

    # Keys only the config has: report, never delete.
    $cfMap = Get-PsdSectionMap -Lines $cf.ToArray()
    foreach ($name in $cfMap.Keys) {
        if (-not $exMap.Contains($name)) { $unknown.Add($name); continue }
        foreach ($k in $cfMap[$name].Keys.Keys) {
            if (-not $exMap[$name].Keys.Contains($k)) { $unknown.Add("$name.$k") }
        }
    }

    if ($added.Count -gt 0) {
        Copy-Item -LiteralPath $ConfigPath -Destination "$ConfigPath.bak" -Force
        Write-Utf8NoBom -Path $ConfigPath -Content ($cf -join $nl)
    }
    [pscustomobject]@{ Added = $added.ToArray(); Unknown = $unknown.ToArray(); Manual = $manual.ToArray() }
}
