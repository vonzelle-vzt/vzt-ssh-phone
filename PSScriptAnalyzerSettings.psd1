@{
    # PSScriptAnalyzer settings for vzt-ssh-phone.
    # These scripts are interactive installers, so a few default rules don't apply.
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Installer/verify scripts print colored, user-facing status to the console
        # on purpose; Write-Host is the correct tool here, not a smell.
        'PSAvoidUsingWriteHost'
    )
}
