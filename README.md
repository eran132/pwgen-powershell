# PwGen for PowerShell

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PwGen?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/PwGen)
[![Downloads](https://img.shields.io/powershellgallery/dt/PwGen?label=downloads)](https://www.powershellgallery.com/packages/PwGen)
[![test](https://github.com/eran132/pwgen-powershell/actions/workflows/test.yml/badge.svg)](https://github.com/eran132/pwgen-powershell/actions/workflows/test.yml)
[![License: GPL-2.0](https://img.shields.io/github/license/eran132/pwgen-powershell)](LICENSE)

A PowerShell port of [pwgen](https://github.com/tytso/pwgen), the password generator that ships with most Linux distributions.

It takes the same options as `pwgen` and uses the same method for easy-to-say passwords, so commands you know from Linux work unchanged on Windows.

```
PS> pwgen -1 12 3
eip6ae4Xip4l
Jooh3ahx9eew
kausieM0aido

PS> pwgen -sy1B 20 2
fCA7bnfi!4)c:3g+zNhb
%@Jw]7=#jNu;]c%aV`_v
```

- Runs on **Windows PowerShell 5.1** and **PowerShell 7+** (Windows, Linux, macOS)
- All randomness comes from the system's cryptographically secure generator (`System.Security.Cryptography.RandomNumberGenerator`), never `Get-Random`
- Pure script module: no compiled code and no dependencies

## Install

```powershell
Install-Module PwGen -Scope CurrentUser
```

## Usage

```
pwgen [ OPTIONS ] [ pw_length ] [ num_pw ]
```

| Option | Long form | Meaning |
|---|---|---|
| `-c` | `--capitalize` | Include at least one capital letter (default) |
| `-A` | `--no-capitalize` | No capital letters |
| `-n` | `--numerals` | Include at least one digit (default) |
| `-0` | `--no-numerals` | No digits |
| `-y` | `--symbols` | Include at least one special character |
| `-s` | `--secure` | Completely random, hard-to-remember passwords |
| `-B` | `--ambiguous` | Avoid look-alike characters such as `0`/`O` and `1`/`l` |
| `-v` | `--no-vowels` | No vowels, so no accidental words (implies `-s`) |
| `-r <chars>` | `--remove-chars=<chars>` | Never use these characters (implies `-s`) |
| `-N <num>` | `--num-passwords=<num>` | Number of passwords |
| `-C` | | Print in columns |
| `-1` | | Print one per line |
| `-h` | `--help` | Show help |

Short flags can be combined (`-sy1B`), and option values can be attached (`-N5`, `-rxyz`) or separate (`-N 5`).

Like `pwgen`, it prints a screen full of passwords in columns when run on its own in a console. When piped or assigned to a variable, it outputs one password per line (one password by default).

### PowerShell extras

| Option | Meaning |
|---|---|
| `--clip` | Copy the password(s) to the clipboard instead of printing them |
| `--secure-string` | Output `[securestring]` objects instead of text |

```powershell
pwgen -s 24 --clip                                              # straight to the clipboard
$cred = [pscredential]::new('svc-user', (pwgen -s 24 --secure-string))
pwgen -1 16 10 | Set-Content passwords.txt                      # works in pipelines
```

### Differences from pwgen

- `-H` (seed from a file's SHA-1) isn't supported; a warning is shown and cryptographic randomness is used instead.
- With `-B`, a letter is never capitalised into a look-alike character (for example `b` into `B`). The original `pwgen` can do this.

## Development

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester ./tests
```

GitHub Actions runs the tests on Windows PowerShell 5.1, PowerShell 7 on Windows, and PowerShell 7 on Linux.

### Releasing

1. Bump `ModuleVersion` in `PwGen/PwGen.psd1` and add a matching `## <version>` section to `CHANGELOG.md`.
2. Commit, then tag and push:
   ```
   git tag v1.2.0
   git push origin main --tags
   ```

The [release workflow](.github/workflows/release.yml) runs the tests, publishes to the PowerShell Gallery using the `PSGALLERY_API_KEY` repository secret, and creates a GitHub release with the `.zip` and `.nupkg` attached.

## Credits and licence

Based on [pwgen](https://github.com/tytso/pwgen), Copyright (C) 2001–2014 Theodore Ts'o.

This port is licensed under the [GNU General Public License v2.0](LICENSE), the same licence as pwgen.
