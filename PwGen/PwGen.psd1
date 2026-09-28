@{
    RootModule           = 'PwGen.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '73633d9b-75fe-4086-bdd8-2d3c6a9ad5ed'
    Author               = 'Eran'
    CompanyName          = 'Community'
    Copyright            = "(c) 2026 Eran. Based on pwgen (c) 2001-2014 Theodore Ts'o. Licensed under GPL-2.0."
    Description          = 'A PowerShell port of pwgen, the Linux pronounceable password generator. Same options as pwgen (-s -y -B -0 -A -v -r -N -1 -C, combined flags like -sy1B, and GNU long options), the same phoneme algorithm, and cryptographically secure randomness. Extras: --clip to copy to the clipboard and --secure-string for SecureString output. Works on Windows PowerShell 5.1 and PowerShell 7 on Windows, Linux and macOS.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @('pwgen')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    FileList             = @('PwGen.psd1', 'PwGen.psm1', 'LICENSE')

    PrivateData          = @{
        PSData = @{
            Tags         = @('pwgen', 'password', 'passwords', 'generator', 'password-generator', 'pronounceable',
                             'random', 'security', 'cli', 'linux', 'Windows', 'Linux', 'MacOS', 'PSEdition_Desktop', 'PSEdition_Core')
            LicenseUri   = 'https://github.com/eran132/pwgen-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eran132/pwgen-powershell'
            ReleaseNotes = 'https://github.com/eran132/pwgen-powershell/blob/main/CHANGELOG.md'
        }
    }
}
