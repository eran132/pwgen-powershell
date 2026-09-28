# Changelog

## 1.0.0 - 2026-09-28

First release.

- `pwgen` command with the same options as Linux pwgen: `-c -A -n -0 -y -s -B -v -r -N -C -1 -h`, combined short flags and GNU-style long options
- Pronounceable passwords use pwgen's phoneme method; `-s` gives fully random passwords
- Cryptographically secure, unbiased randomness
- PowerShell extras: `--clip` and `--secure-string`
- Supports Windows PowerShell 5.1 and PowerShell 7+ on Windows, Linux and macOS
