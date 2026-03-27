# =============================================================================
# windows.config.psd1 - Windows setup configuration
#
# true  = install
# false = skip
# =============================================================================
@{

    # -------------------------------------------------------------------------
    # Git configuration (applied at the end with git config --global)
    # Leave empty "" to skip configuration
    # -------------------------------------------------------------------------
    Git = @{
        UserName  = ""
        UserEmail = ""
    }

    # -------------------------------------------------------------------------
    # Package Managers
    # Chocolatey and winget source update are always run (setup base)
    # -------------------------------------------------------------------------
    PackageManagers = @{
        Chocolatey = $true
    }

    # -------------------------------------------------------------------------
    # Terminal and Shell
    # -------------------------------------------------------------------------
    Terminal = @{
        WindowsTerminal        = $true
        PowerShell7            = $true
        SetPowerShell7AsDefault = $true   # set PS7 as default in Windows Terminal and VS Code
        Git                    = $true
        OhMyPosh               = $true
        Starship               = $false   # alternative to OhMyPosh - pick one
        Zoxide                 = $true
        Fzf                    = $true
    }

    # -------------------------------------------------------------------------
    # Editors and IDEs
    # -------------------------------------------------------------------------
    Editors = @{
        VSCode            = $true
        Cursor            = $true
        # JetBrains: install Toolbox first; IDEs install via Toolbox (API) with winget fallback
        JetBrainsToolbox  = $false    # Toolbox manages installs, updates and licenses
        PyCharm           = $false    # Community (free) - set PyCharmProfessional for paid license
        PyCharmProfessional = $true # Professional requires active JetBrains license
        WebStorm          = $true    # requires active JetBrains license
        DataGrip          = $true   # database IDE - requires active JetBrains license
    }

    # -------------------------------------------------------------------------
    # Git and Version Control
    # -------------------------------------------------------------------------
    GitTools = @{
        GitHubCLI  = $true
        GitKraken  = $true   # optional - visual client
        Delta      = $false
    }

    # -------------------------------------------------------------------------
    # Runtimes and Version Managers
    # -------------------------------------------------------------------------
    Runtimes = @{
        Mise       = $true    # universal version manager (recommended)
        PyenvWin   = $true   # alternative to mise for Python
        NvmWindows = $false   # alternative to mise for Node
        Python313  = $false
        NodeLTS    = $false   # managed by mise - install via: mise use -g node@lts
        Java21     = $false
        Uv         = $true    # ultra-fast Python package manager
        Pnpm       = $true    # efficient Node package manager
    }

    # -------------------------------------------------------------------------
    # Databases
    # -------------------------------------------------------------------------
    Database = @{
        PostgreSQL16    = $false
        DBeaver         = $true
        TablePlus       = $false   # paid after trial
        PgAdmin         = $true    # alternative to DBeaver for Postgres
        RedisInsight    = $false
        SQLiteBrowser   = $false
    }

    # -------------------------------------------------------------------------
    # API and HTTP Testing
    # -------------------------------------------------------------------------
    API = @{
        Postman  = $true   # heavy - pick one HTTP client
        Insomnia = $false  # alternative to Postman
        Bruno    = $false   # lightweight, open-source, file-based
    }

    # -------------------------------------------------------------------------
    # CLI Utilities
    # -------------------------------------------------------------------------
    CLI = @{
        Ripgrep = $true
        Fd      = $true
        Bat     = $true
        Eza     = $true
        Delta   = $true
        Jq      = $true
        Yq      = $true
        Wget    = $true
        Make    = $true
        Sudo    = $true
        Just    = $true
        Curl    = $true
    }

    # -------------------------------------------------------------------------
    # Security and Authentication
    # -------------------------------------------------------------------------
    Security = @{
        Bitwarden   = $true
        Gpg4win     = $true
        OpenSSH     = $true
    }

    # -------------------------------------------------------------------------
    # Productivity
    # -------------------------------------------------------------------------
    Productivity = @{
        Obsidian    = $true
        Notion      = $false   # optional
        Slack       = $false   # install if used at work
        Discord     = $false   # install if used
        ShareX      = $true
        PowerToys   = $false
        Everything  = $true
        WizTree     = $true    # disk usage analyzer
        AutoHotkey  = $false   # optional - keyboard automation
        DrawIO      = $true    # diagram and flowchart editor (diagrams.net)
    }

    # -------------------------------------------------------------------------
    # Utilities
    # -------------------------------------------------------------------------
    Utilities = @{
        SevenZip   = $true    # archive manager (free, open-source)
        WinRAR     = $false   # archive manager (trialware - pick one)
        VLC        = $true    # media player
        WinSCP     = $true    # SFTP/FTP client
        PuTTY      = $true    # SSH/Telnet client
        NotepadPP  = $true    # text editor
        VCRedist   = $true    # Visual C++ Redistributables (2015-2022 x64 + x86)
    }

    # -------------------------------------------------------------------------
    # Browsers
    # -------------------------------------------------------------------------
    Browsers = @{
        Chrome            = $true
        FirefoxDev        = $true
    }

    # -------------------------------------------------------------------------
    # Fonts
    # -------------------------------------------------------------------------
    Fonts = @{
        JetBrainsMono = $true
        FiraCode      = $true
        CascadiaCode  = $true
        NerdFontsHack = $true
    }

    # -------------------------------------------------------------------------
    # VS Code Extensions
    # -------------------------------------------------------------------------
    VSCodeExtensions = @{
        # Python / Django
        Python          = $true
        Pylance         = $true
        Debugpy         = $true
        VscodeDjango    = $true
        AutoCloseTag    = $true

        # Angular / TypeScript
        NgTemplate      = $true
        TypeScriptNext  = $true
        ESLint          = $true
        Prettier        = $true

        # General
        GitLens         = $true
        GitGraph        = $true
        DockerExt       = $true
        RemoteContainers = $true
        MaterialIcons   = $true
        IndentRainbow   = $true
        SpellChecker    = $true
    }
}
