#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $script:Manifest = Join-Path $PSScriptRoot '../PwGen/PwGen.psd1'
    Import-Module $Manifest -Force
    $script:Ambiguous = '[B8G6I1l0OQDS5Z2]'
}

Describe 'Module' {
    It 'exports only pwgen' {
        (Get-Module PwGen).ExportedCommands.Keys | Should -Be @('pwgen')
    }

    It 'passes Test-ModuleManifest' {
        { Test-ModuleManifest $Manifest -ErrorAction Stop } | Should -Not -Throw
    }
}

Describe 'Pronounceable passwords (default)' {
    BeforeAll { $script:pws = pwgen -1 12 300 }

    It 'returns the requested count and length' {
        $pws.Count | Should -Be 300
        $pws | ForEach-Object { $_.Length | Should -Be 12 }
    }

    It 'always includes a capital letter and a digit' {
        $pws | ForEach-Object { $_ | Should -MatchExactly '[A-Z]'; $_ | Should -Match '[0-9]' }
    }

    It 'uses only letters and digits' {
        $pws | ForEach-Object { $_ | Should -Match '^[A-Za-z0-9]+$' }
    }

    It 'defaults to one 8-character password when output is not columnar' {
        $pw = @(pwgen -1)
        $pw.Count | Should -Be 1
        $pw[0].Length | Should -Be 8
    }

    It '-A and -0 remove capitals and digits' {
        pwgen -A0 -1 10 100 | ForEach-Object { $_ | Should -MatchExactly '^[a-z]{10}$' }
    }

    It '-y includes a symbol' {
        pwgen -y -1 10 100 | ForEach-Object { $_ | Should -Match '[^A-Za-z0-9]' }
    }

    It '-B avoids ambiguous characters' {
        pwgen -B -1 10 300 | ForEach-Object { $_ | Should -Not -MatchExactly $Ambiguous }
    }
}

Describe 'Secure passwords (-s)' {
    It 'includes lower, upper, digit and symbol with -sy' {
        pwgen -sy -1 12 200 | ForEach-Object {
            $_.Length | Should -Be 12
            $_ | Should -MatchExactly '[a-z]'
            $_ | Should -MatchExactly '[A-Z]'
            $_ | Should -Match '[0-9]'
            $_ | Should -Match '[^A-Za-z0-9]'
        }
    }

    It '-r removes characters and implies -s' {
        pwgen -1 -r abcdefXYZ789 16 100 | ForEach-Object { $_ | Should -Not -MatchExactly '[abcdefXYZ789]' }
    }

    It '-v removes vowels and look-alike digits' {
        pwgen -v -1 16 100 | ForEach-Object { $_ | Should -Not -Match '[aeiouy01]' }
    }

    It 'lengths under 5 still work' {
        pwgen -1 3 50 | ForEach-Object { $_.Length | Should -Be 3 }
        pwgen -1 1 50 | ForEach-Object { $_ | Should -MatchExactly '^[a-z]$' }
    }

    It 'is roughly uniform across the alphabet' {
        $groups = pwgen -1 1 13000 | Group-Object -CaseSensitive
        $groups.Count | Should -Be 26
        $groups | ForEach-Object { $_.Count | Should -BeGreaterThan 350; $_.Count | Should -BeLessThan 650 }
    }
}

Describe 'Option parsing' {
    It 'accepts combined short flags' {
        pwgen -sy1B 20 5 | ForEach-Object {
            $_.Length | Should -Be 20
            $_ | Should -Not -MatchExactly $Ambiguous
        }
    }

    It 'accepts long options with = and with a separate value' {
        pwgen -1 --num-passwords=4 --remove-chars=abc 10 | Should -HaveCount 4
        pwgen -1 --num-passwords 4 10 | Should -HaveCount 4
    }

    It 'accepts -N with attached and separate values' {
        pwgen -1 -N3 10 | Should -HaveCount 3
        pwgen -1 -N 3 10 | Should -HaveCount 3
    }

    It 'lets a later -c/-n undo -A/-0' {
        pwgen -A -c -0 -n -1 12 50 | ForEach-Object { $_ | Should -MatchExactly '[A-Z]'; $_ | Should -Match '[0-9]' }
    }

    It 'prints usage for -h and --help' {
        pwgen -h | Should -BeLike 'Usage: pwgen*'
        pwgen --help | Should -BeLike 'Usage: pwgen*'
    }

    It 'rejects <Case>' -TestCases @(
        @{ Case = 'unknown short option'; Argv = @('-x') }
        @{ Case = 'unknown long option'; Argv = @('--bogus') }
        @{ Case = 'non-numeric length'; Argv = @('abc') }
        @{ Case = 'zero length'; Argv = @('0') }
        @{ Case = 'too many arguments'; Argv = @('8', '2', '3') }
        @{ Case = 'missing -r value'; Argv = @('-r') }
        @{ Case = 'value on a flag'; Argv = @('--secure=yes') }
    ) {
        { pwgen @Argv } | Should -Throw 'pwgen:*'
    }

    It 'fails clearly when every character is removed' {
        { pwgen -s -A0 -r abcdefghijklmnopqrstuvwxyz 8 } | Should -Throw '*No characters left*'
    }
}

Describe 'Output modes' {
    It '-C prints columns separated by spaces' {
        $lines = @(pwgen -C 10 12)
        $lines.Count | Should -BeLessThan 12
        ($lines -join ' ').Split(' ') | Should -HaveCount 12
    }

    It '--secure-string returns SecureString objects' {
        $s = @(pwgen -s 20 2 --secure-string)
        $s | Should -HaveCount 2
        $s[0] | Should -BeOfType [securestring]
        [System.Net.NetworkCredential]::new('', $s[0]).Password.Length | Should -Be 20
    }
}
