#Requires -Version 5.1
<#
    PwGen - a PowerShell port of pwgen, the pronounceable password generator.

    Copyright (C) 2026 Eran
    Based on pwgen, Copyright (C) 2001-2014 Theodore Ts'o <https://github.com/tytso/pwgen>

    This program is free software; you can redistribute it and/or modify it under
    the terms of the GNU General Public License version 2 as published by the
    Free Software Foundation.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
    FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#>
Set-StrictMode -Version Latest

# Character sets (same as pwgen)
$script:Digits    = '0123456789'
$script:Uppers    = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
$script:Lowers    = 'abcdefghijklmnopqrstuvwxyz'
$script:SymbolSet = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
$script:Ambiguous = 'B8G6I1l0OQDS5Z2'
$script:VowelSet  = '01aeiouyAEIOUY'

# Phoneme element flags
$script:F_CONSONANT = 1
$script:F_VOWEL     = 2
$script:F_DIPHTHONG = 4
$script:F_NOTFIRST  = 8

$C = $script:F_CONSONANT; $V = $script:F_VOWEL; $D = $script:F_DIPHTHONG; $NF = $script:F_NOTFIRST
$elements = [ordered]@{
    a = $V;  ae = $V -bor $D; ah = $V -bor $D; ai = $V -bor $D
    b = $C;  c = $C; ch = $C -bor $D; d = $C
    e = $V;  ee = $V -bor $D; ei = $V -bor $D
    f = $C;  g = $C; gh = $C -bor $D -bor $NF; h = $C
    i = $V;  ie = $V -bor $D
    j = $C;  k = $C; l = $C; m = $C; n = $C; ng = $C -bor $D -bor $NF
    o = $V;  oh = $V -bor $D; oo = $V -bor $D
    p = $C;  ph = $C -bor $D; qu = $C -bor $D; r = $C; s = $C; sh = $C -bor $D
    t = $C;  th = $C -bor $D
    u = $V;  v = $C; w = $C; x = $C; y = $C; z = $C
}
$script:ElemStr   = [string[]]@($elements.Keys)
$script:ElemFlags = [int[]]@($elements.Values)
Remove-Variable C, V, D, NF, elements

# Unbiased CSPRNG integer in [0, max). RandomNumberGenerator.GetInt32 only exists on
# .NET Core 3+, so use rejection sampling over GetBytes to also run on Windows PowerShell 5.1.
class PwGenRng {
    static [System.Security.Cryptography.RandomNumberGenerator] $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    static [byte[]] $Buf = [byte[]]::new(4)

    static [int] GetInt32([int]$Max) {
        if ($Max -le 1) { return 0 }
        $range = [long]4294967296
        $limit = $range - ($range % $Max)
        while ($true) {
            [PwGenRng]::Rng.GetBytes([PwGenRng]::Buf)
            $v = [long][BitConverter]::ToUInt32([PwGenRng]::Buf, 0)
            if ($v -lt $limit) { return [int]($v % $Max) }
        }
        return 0
    }
}


function script:Get-PhonemePassword {
    param([int]$Length, [bool]$Upper, [bool]$Digit, [bool]$Symbol, [bool]$NoAmbiguous)

    $ambChars = $script:Ambiguous.ToCharArray()
    $n = $script:ElemStr.Length

    while ($true) {
        $sb = [System.Text.StringBuilder]::new($Length + 1)
        $needUpper = $Upper; $needDigit = $Digit; $needSymbol = $Symbol
        $prev = 0
        $first = $true
        $shouldBe = if ([PwGenRng]::GetInt32(2)) { $script:F_VOWEL } else { $script:F_CONSONANT }

        while ($sb.Length -lt $Length) {
            $i = [PwGenRng]::GetInt32($n)
            $str = $script:ElemStr[$i]
            $flags = $script:ElemFlags[$i]

            if (-not ($flags -band $shouldBe)) { continue }
            if ($first -and ($flags -band $script:F_NOTFIRST)) { continue }
            # Don't allow a vowel followed by a vowel/diphthong pair
            if (($prev -band $script:F_VOWEL) -and ($flags -band $script:F_VOWEL) -and ($flags -band $script:F_DIPHTHONG)) { continue }
            if ($str.Length -gt ($Length - $sb.Length)) { continue }
            if ($NoAmbiguous -and $str.IndexOfAny($ambChars) -ge 0) { continue }

            if ($Upper -and ($first -or ($flags -band $script:F_CONSONANT)) -and [PwGenRng]::GetInt32(10) -lt 2) {
                $up = [char]::ToUpperInvariant($str[0])
                if (-not ($NoAmbiguous -and $script:Ambiguous.Contains($up))) {
                    $str = $up + $str.Substring(1)
                    $needUpper = $false
                }
            }
            [void]$sb.Append($str)
            if ($sb.Length -ge $Length) { break }

            if ($Digit -and -not $first -and [PwGenRng]::GetInt32(10) -lt 3) {
                do { $ch = $script:Digits[[PwGenRng]::GetInt32(10)] } while ($NoAmbiguous -and $script:Ambiguous.Contains($ch))
                [void]$sb.Append($ch)
                $needDigit = $false
                # Restart the phoneme sequence after a digit
                $first = $true
                $prev = 0
                $shouldBe = if ([PwGenRng]::GetInt32(2)) { $script:F_VOWEL } else { $script:F_CONSONANT }
                continue
            }

            if ($Symbol -and -not $first -and [PwGenRng]::GetInt32(10) -lt 2) {
                do { $ch = $script:SymbolSet[[PwGenRng]::GetInt32($script:SymbolSet.Length)] } while ($NoAmbiguous -and $script:Ambiguous.Contains($ch))
                [void]$sb.Append($ch)
                $needSymbol = $false
            }

            if ($shouldBe -eq $script:F_CONSONANT) {
                $shouldBe = $script:F_VOWEL
            }
            elseif (($prev -band $script:F_VOWEL) -or ($flags -band $script:F_DIPHTHONG) -or [PwGenRng]::GetInt32(10) -gt 3) {
                $shouldBe = $script:F_CONSONANT
            }
            else {
                $shouldBe = $script:F_VOWEL
            }
            $prev = $flags
            $first = $false
        }

        if (-not ($needUpper -or $needDigit -or $needSymbol)) { return $sb.ToString() }
    }
}

function script:Get-RandomPassword {
    param([int]$Length, [bool]$Upper, [bool]$Digit, [bool]$Symbol,
          [bool]$NoAmbiguous, [bool]$NoVowels, [string]$RemoveChars)

    $exclude = [System.Collections.Generic.HashSet[char]]::new()
    if ($NoAmbiguous) { $script:Ambiguous.ToCharArray() | ForEach-Object { [void]$exclude.Add($_) } }
    if ($NoVowels)    { $script:VowelSet.ToCharArray()  | ForEach-Object { [void]$exclude.Add($_) } }
    if ($RemoveChars) { $RemoveChars.ToCharArray()      | ForEach-Object { [void]$exclude.Add($_) } }

    $filter = { param($set) -join ($set.ToCharArray() | Where-Object { -not $exclude.Contains($_) }) }

    # Each class that is enabled and still non-empty must appear at least once
    $classes = [System.Collections.Generic.List[string]]::new()
    $classes.Add((& $filter $script:Lowers))
    if ($Upper)  { $classes.Add((& $filter $script:Uppers)) }
    if ($Digit)  { $classes.Add((& $filter $script:Digits)) }
    if ($Symbol) { $classes.Add((& $filter $script:SymbolSet)) }
    $required = @($classes | Where-Object { $_.Length -gt 0 })
    $charset = -join $required

    if ($charset.Length -eq 0) { throw 'No characters left to generate a password from (check -RemoveChars / -NoVowels / -NoAmbiguous).' }
    if ($required.Count -gt $Length) { $required = @() }   # too short to satisfy every class

    while ($true) {
        $chars = [char[]]::new($Length)
        for ($i = 0; $i -lt $Length; $i++) { $chars[$i] = $charset[[PwGenRng]::GetInt32($charset.Length)] }
        $pw = [string]::new($chars)
        $ok = $true
        foreach ($cls in $required) {
            if ($pw.IndexOfAny($cls.ToCharArray()) -lt 0) { $ok = $false; break }
        }
        if ($ok) { return $pw }
    }
}

function script:New-PwGenBatch {
    param([int]$Length, [int]$Count, [bool]$Secure, [bool]$Symbols, [bool]$NoCapitalize,
          [bool]$NoNumerals, [bool]$NoAmbiguous, [bool]$NoVowels, [string]$RemoveChars)

    $upper = -not $NoCapitalize
    $digit = -not $NoNumerals
    # Same short-length rules as pwgen
    if ($Length -le 2) { $upper = $false }
    if ($Length -le 1) { $digit = $false }
    # Like pwgen: -v, -r and very short lengths use the fully random generator
    $useRandom = $Secure -or $NoVowels -or $RemoveChars -or $Length -lt 5

    for ($k = 0; $k -lt $Count; $k++) {
        if ($useRandom) {
            Get-RandomPassword -Length $Length -Upper $upper -Digit $digit -Symbol $Symbols `
                -NoAmbiguous $NoAmbiguous -NoVowels $NoVowels -RemoveChars $RemoveChars
        }
        else {
            Get-PhonemePassword -Length $Length -Upper $upper -Digit $digit -Symbol $Symbols -NoAmbiguous $NoAmbiguous
        }
    }
}

function script:ConvertTo-PwGenNumber([string]$Value, [string]$What, [int]$Max) {
    $n = 0
    if (-not [int]::TryParse($Value, [ref]$n) -or $n -lt 1 -or $n -gt $Max) {
        throw "pwgen: invalid $What '$Value' (must be 1-$Max). Try 'pwgen --help'."
    }
    $n
}

$script:PwgenUsage = @'
Usage: pwgen [ OPTIONS ] [ pw_length ] [ num_pw ]

Options supported by pwgen:
  -c or --capitalize
        Include at least one capital letter in the password (default)
  -A or --no-capitalize
        Don't include capital letters in the password
  -n or --numerals
        Include at least one number in the password (default)
  -0 or --no-numerals
        Don't include numbers in the password
  -y or --symbols
        Include at least one special symbol in the password
  -r <chars> or --remove-chars=<chars>
        Remove characters from the set of characters to generate passwords
  -s or --secure
        Generate completely random passwords
  -B or --ambiguous
        Don't include ambiguous characters in the password
  -h or --help
        Print a help message
  -N <num> or --num-passwords=<num>
        Number of passwords to generate
  -C
        Print the generated passwords in columns
  -1
        Don't print the generated passwords in columns
  -v or --no-vowels
        Do not use any vowels so as to avoid accidental nasty words

PowerShell extras:
  --clip
        Copy the password(s) to the clipboard instead of printing them
  --secure-string
        Output [securestring] objects instead of text (implies -1)

Randomness comes from System.Security.Cryptography.RandomNumberGenerator.
The -H option (seed from a file's SHA1) is not supported.
'@

function pwgen {
    <#
    .SYNOPSIS
        Generates pronounceable or fully random passwords, like the Linux pwgen utility.
    .DESCRIPTION
        A PowerShell port of pwgen. Accepts the same options as pwgen, including combined
        short flags (-sy1B) and GNU-style long options (--remove-chars=xyz).

        By default it generates pronounceable passwords of 8 characters containing at least
        one capital letter and one digit. When writing to the console it prints a screen
        full of passwords in columns; when piped or assigned it outputs one password per line.

        Run 'pwgen --help' for the full list of options.
    .EXAMPLE
        pwgen
        Prints a screen full of 8-character pronounceable passwords.
    .EXAMPLE
        pwgen -sy1B 20 3
        Three fully random 20-character passwords with symbols and no ambiguous characters.
    .EXAMPLE
        pwgen -s 24 --clip
        Copies one random 24-character password to the clipboard.
    .EXAMPLE
        $cred = [pscredential]::new('svc-user', (pwgen -s 24 --secure-string))
        Creates a credential without the password ever being stored as plain text in a variable.
    .LINK
        https://github.com/eran132/pwgen-powershell
    #>

    # Intentionally a simple (non-advanced) function so that raw pwgen-style
    # flags such as -sy, -0, -1, --remove-chars=xyz arrive untouched in $args.
    $p = @{ Secure = $false; Symbols = $false; NoCapitalize = $false; NoNumerals = $false
            NoAmbiguous = $false; NoVowels = $false; RemoveChars = '' }
    $columns = $null
    $clip = $false
    $secureString = $false
    $count = $null
    $positional = [System.Collections.Generic.List[string]]::new()

    $argv = @($args | ForEach-Object { "$_" })
    for ($i = 0; $i -lt $argv.Count; $i++) {
        $a = $argv[$i]

        if ($a -eq '--') {
            if ($i + 1 -lt $argv.Count) { $positional.AddRange([string[]]$argv[($i + 1)..($argv.Count - 1)]) }
            break
        }

        if ($a.StartsWith('--')) {
            $name, $val = $a.Substring(2) -split '=', 2
            $needsValue = $name -in 'remove-chars', 'num-passwords'
            if ($needsValue -and $null -eq $val) {
                if ($i + 1 -ge $argv.Count) { throw "pwgen: option '--$name' requires an argument" }
                $val = $argv[++$i]
            }
            elseif (-not $needsValue -and $null -ne $val) {
                throw "pwgen: option '--$name' doesn't allow an argument"
            }
            switch ($name) {
                'capitalize'    { $p.NoCapitalize = $false }
                'no-capitalize' { $p.NoCapitalize = $true }
                'numerals'      { $p.NoNumerals = $false }
                'no-numerals'   { $p.NoNumerals = $true }
                'symbols'       { $p.Symbols = $true }
                'secure'        { $p.Secure = $true }
                'ambiguous'     { $p.NoAmbiguous = $true }
                'no-vowels'     { $p.NoVowels = $true }
                'remove-chars'  { $p.RemoveChars = $val }
                'num-passwords' { $count = ConvertTo-PwGenNumber $val 'number of passwords' 1000000 }
                'clip'          { $clip = $true }
                'secure-string' { $secureString = $true }
                'help'          { return $script:PwgenUsage }
                default         { throw "pwgen: unrecognized option '--$name'. Try 'pwgen --help'." }
            }
            continue
        }

        if ($a.Length -gt 1 -and $a[0] -eq '-') {
            for ($j = 1; $j -lt $a.Length; $j++) {
                $o = $a[$j]
                $rest = $a.Substring($j + 1)
                switch -CaseSensitive ($o) {
                    'c' { $p.NoCapitalize = $false }
                    'A' { $p.NoCapitalize = $true }
                    'n' { $p.NoNumerals = $false }
                    '0' { $p.NoNumerals = $true }
                    'y' { $p.Symbols = $true }
                    's' { $p.Secure = $true }
                    'B' { $p.NoAmbiguous = $true }
                    'v' { $p.NoVowels = $true }
                    'C' { $columns = $true }
                    '1' { $columns = $false }
                    'h' { return $script:PwgenUsage }
                    'H' {
                        Write-Warning 'pwgen: -H (sha1 seed) is not supported; using cryptographic randomness.'
                        if (-not $rest) { $i++ }
                        $j = $a.Length
                    }
                    { $_ -ceq 'r' -or $_ -ceq 'N' } {
                        $v = if ($rest) { $rest } elseif ($i + 1 -lt $argv.Count) { $argv[++$i] } else { throw "pwgen: option requires an argument -- '$o'" }
                        if ($o -ceq 'r') { $p.RemoveChars = $v } else { $count = ConvertTo-PwGenNumber $v 'number of passwords' 1000000 }
                        $j = $a.Length
                    }
                    default { throw "pwgen: invalid option -- '$o'. Try 'pwgen --help'." }
                }
            }
            continue
        }

        $positional.Add($a)
    }

    if ($positional.Count -gt 2) { throw "pwgen: too many arguments. Try 'pwgen --help'." }
    $length = if ($positional.Count -ge 1) { ConvertTo-PwGenNumber $positional[0] 'password length' 4096 } else { 8 }
    if ($positional.Count -ge 2) { $count = ConvertTo-PwGenNumber $positional[1] 'number of passwords' 1000000 }

    # Like pwgen: columns by default when writing straight to an interactive console
    if ($null -eq $columns) {
        $columns = -not $clip -and -not $secureString -and -not [Console]::IsOutputRedirected -and
                   $MyInvocation.PipelinePosition -eq $MyInvocation.PipelineLength
    }
    if ($secureString) { $columns = $false }

    $width = 80
    try { if ($Host.UI.RawUI.WindowSize.Width -gt 0) { $width = $Host.UI.RawUI.WindowSize.Width } } catch { Write-Debug "pwgen: console width unavailable, using $width columns" }
    $perLine = [Math]::Max(1, [Math]::Floor(($width - 1) / ($length + 1)))

    if ($null -eq $count) { $count = if ($columns) { $perLine * 20 } else { 1 } }

    $pws = @(New-PwGenBatch -Length $length -Count $count @p)

    if ($clip) {
        Set-Clipboard -Value $pws
        Write-Information "Copied $count password(s) to the clipboard." -InformationAction Continue
        return
    }
    if ($secureString) {
        foreach ($pw in $pws) {
            $ss = [securestring]::new()
            foreach ($ch in $pw.ToCharArray()) { $ss.AppendChar($ch) }
            $ss.MakeReadOnly()
            $ss
        }
        return
    }
    if ($columns) {
        for ($k = 0; $k -lt $pws.Count; $k += $perLine) {
            $pws[$k..([Math]::Min($k + $perLine, $pws.Count) - 1)] -join ' '
        }
    }
    else { $pws }
}

Export-ModuleMember -Function pwgen
