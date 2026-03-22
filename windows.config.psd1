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
        WindowsTerminal = $true
        PowerShell7     = $true
        Git             = $true
        OhMyPosh        = $true
        Starship        = $false   # alternative to OhMyPosh - pick one
        Zoxide          = $true
        Fzf             = $true
    }

    # -------------------------------------------------------------------------
    # Editors and IDEs
    # -------------------------------------------------------------------------
    Editors = @{
        VSCode    = $true
        Cursor    = $true
        PyCharm   = $true   # heavy - install manually if needed
        WebStorm  = $true   # heavy - install manually if needed
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
        PyenvWin   = $false   # alternative to mise for Python
        NvmWindows = $false   # alternative to mise for Node
        Python313  = $false
        NodeLTS    = $true
        Java21     = $true
        Uv         = $true    # ultra-fast Python package manager
        Pnpm       = $true    # efficient Node package manager
    }

    # -------------------------------------------------------------------------
    # Databases
    # -------------------------------------------------------------------------
    Database = @{
        PostgreSQL16    = $true
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
        Bruno    = $true   # lightweight, open-source, file-based
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
        PowerToys   = $true
        Everything  = $true
        AutoHotkey  = $false   # optional - keyboard automation
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
