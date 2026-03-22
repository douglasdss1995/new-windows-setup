# =============================================================================
# windows.config.psd1 - Configuracao do setup Windows
#
# true  = instalar
# false = pular
# =============================================================================
@{

    # -------------------------------------------------------------------------
    # Configuracao do Git (aplicada ao final com git config --global)
    # Deixe vazio "" para pular a configuracao
    # -------------------------------------------------------------------------
    Git = @{
        UserName  = ""
        UserEmail = ""
    }

    # -------------------------------------------------------------------------
    # Gerenciadores de Pacotes
    # Chocolatey e a atualizacao do winget sao sempre executados (base do setup)
    # -------------------------------------------------------------------------
    PackageManagers = @{
        Chocolatey = $true
    }

    # -------------------------------------------------------------------------
    # Terminal e Shell
    # -------------------------------------------------------------------------
    Terminal = @{
        WindowsTerminal = $true
        PowerShell7     = $true
        Git             = $true
        OhMyPosh        = $true
        Starship        = $false   # alternativa ao OhMyPosh - escolha um
        Zoxide          = $true
        Fzf             = $true
    }

    # -------------------------------------------------------------------------
    # Editores e IDEs
    # -------------------------------------------------------------------------
    Editors = @{
        VSCode    = $true
        Cursor    = $true
        PyCharm   = $false   # pesado - instale manualmente se necessario
        WebStorm  = $false   # pesado - instale manualmente se necessario
    }

    # -------------------------------------------------------------------------
    # Git e Controle de Versao
    # -------------------------------------------------------------------------
    GitTools = @{
        GitHubCLI  = $true
        GitKraken  = $false   # opcional - cliente visual
        Delta      = $true
    }

    # -------------------------------------------------------------------------
    # Runtimes e Gerenciadores de Versao
    # -------------------------------------------------------------------------
    Runtimes = @{
        Mise       = $true    # gerenciador universal (recomendado)
        PyenvWin   = $false   # alternativa ao mise para Python
        NvmWindows = $false   # alternativa ao mise para Node
        Python313  = $true
        NodeLTS    = $true
        Java21     = $true
        Uv         = $true    # gerenciador de pacotes Python ultrarapido
        Pnpm       = $true    # gerenciador de pacotes Node eficiente
    }

    # -------------------------------------------------------------------------
    # Banco de Dados
    # -------------------------------------------------------------------------
    Database = @{
        PostgreSQL16    = $true
        DBeaver         = $true
        TablePlus       = $false   # pago apos trial
        PgAdmin         = $false   # alternativa ao DBeaver para Postgres
        RedisInsight    = $true
        SQLiteBrowser   = $true
    }

    # -------------------------------------------------------------------------
    # API e Testes HTTP
    # -------------------------------------------------------------------------
    API = @{
        Postman  = $false   # pesado - escolha um cliente HTTP
        Insomnia = $false   # alternativa ao Postman
        Bruno    = $true    # leve, open-source, baseado em arquivos
    }

    # -------------------------------------------------------------------------
    # Utilitarios de Linha de Comando
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
    # Seguranca e Autenticacao
    # -------------------------------------------------------------------------
    Security = @{
        Bitwarden   = $true
        Gpg4win     = $true
        OpenSSH     = $true
    }

    # -------------------------------------------------------------------------
    # Produtividade
    # -------------------------------------------------------------------------
    Productivity = @{
        Obsidian    = $true
        Notion      = $false   # opcional
        Slack       = $false   # instale se usar no trabalho
        Discord     = $false   # instale se usar
        ShareX      = $true
        PowerToys   = $true
        Everything  = $true
        AutoHotkey  = $false   # opcional - automacao de teclado
    }

    # -------------------------------------------------------------------------
    # Navegadores
    # -------------------------------------------------------------------------
    Browsers = @{
        Chrome            = $true
        FirefoxDev        = $true
    }

    # -------------------------------------------------------------------------
    # Fontes
    # -------------------------------------------------------------------------
    Fonts = @{
        JetBrainsMono = $true
        FiraCode      = $true
        CascadiaCode  = $true
        NerdFontsHack = $true
    }

    # -------------------------------------------------------------------------
    # VS Code - Extensoes
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

        # Geral
        GitLens         = $true
        GitGraph        = $true
        DockerExt       = $true
        RemoteContainers = $true
        MaterialIcons   = $true
        IndentRainbow   = $true
        SpellChecker    = $true
    }
}
