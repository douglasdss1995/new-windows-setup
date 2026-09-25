@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # These are interactive console scripts: colored Write-Host output is the UI.
        'PSAvoidUsingWriteHost',
        # Helpers like Install-Pkg / Write-Step are internal, not public cmdlets.
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        # Files are UTF-8 without BOM (see .editorconfig).
        'PSUseBOMForUnicodeEncodedFile',
        # Official installers (Chocolatey, pnpm) are documented as iex one-liners.
        'PSAvoidUsingInvokeExpression',
        # Pester BeforeAll/BeforeDiscovery variables are used in other blocks; the rule can't see that.
        'PSUseDeclaredVarsMoreThanAssignments'
    )
}
