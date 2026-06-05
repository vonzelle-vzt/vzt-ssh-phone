# Contributing to vzt-ssh-phone

Thanks for your interest! This is a small, focused tool — a self-elevating PowerShell installer that sets up remote SSH into a Windows PC over Tailscale. Contributions that keep it **simple, safe, and idempotent** are very welcome.

## Ways to contribute
- 🐛 **Bug reports** — open an [issue](https://github.com/vonzelle-vzt/vzt-ssh-phone/issues) with your Windows version, what you ran, and the exact output/error.
- 💡 **Improvements** — clearer docs, better gotcha handling, new client guides, extra `-Install*` options.
- 🔌 **New scenarios** — e.g. an optional Mosh/WSL path, a custom-port hardening guide, additional SSH clients.

## Project layout
| File | Purpose |
|---|---|
| `install.ps1` | The installer. Self-elevating, idempotent. All setup logic lives here. |
| `verify.ps1` | Read-only health check. |
| `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | Agent-takeover instructions. **Keep these in sync** with installer flags. |
| `README.md` | User docs. |

## Local development & testing
You'll need a **Windows 10/11** machine (ideally a throwaway VM, since the script changes system state).

1. **Syntax-check** before every commit:
   ```powershell
   $e=$null
   [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\install.ps1),[ref]$null,[ref]$e) | Out-Null
   if($e.Count){ $e } else { 'install.ps1 OK' }
   ```
   Do the same for `verify.ps1`.
2. **Test on a clean VM** if you change install behavior — confirm a fresh run reaches `DONE - SSH server is live` and that `verify.ps1` reports everything green.
3. **Test idempotency** — run `install.ps1` twice; the second run must not error and should report "already installed / present".
4. **Test the relevant path** — if you touch the standalone-OpenSSH fallback, simulate it (e.g. with a pending reboot, or temporarily bypass the capability branch). If you touch key auth, test both admin and standard-user accounts.

## Coding conventions
- **PowerShell 5.1 compatible** (`#Requires -Version 5.1`). Don't rely on PS7-only syntax.
- **Idempotent always** — check before you change (`if (Get-Service sshd) {...}`). Re-running must be safe.
- **Use the existing helpers** — `Step` / `Info` / `Ok` / `Warn` for output, and `Emit` for agent status. New phases should call `Step` (it auto-emits progress) so `-StatusFile` consumers see them.
- **Forward new params through self-elevation** (the `if ($PSCommandPath)` block) so they survive the UAC relaunch.
- **Keep it dependency-free** — no external modules; standard cmdlets + bundled tools only.
- **Comment the *why*** for any Windows quirk (these are the valuable parts).

## Security rules (important)
- **Never commit keys or secrets.** Examples in docs must be **truncated placeholders** (`ssh-ed25519 AAAA...`), never real keys. `.gitignore` blocks `*_key`, `id_*`, `*.pem`, and logs — don't override it.
- **Don't weaken defaults** — Tailscale-only, key auth, locked-down `administrators_authorized_keys` ACL. If you add a public-internet/port-forward path, gate it behind an explicit flag and document the risk.
- Found a vulnerability? Please **report privately** via a GitHub security advisory rather than a public issue.

## Pull requests
1. Fork, branch from `main` (e.g. `fix/dism-timeout`).
2. Make the change; run the syntax check + idempotency test above.
3. If you added/changed an installer flag, **update `README.md` (Options & flags) and `AGENTS.md`** in the same PR.
4. Write a clear PR description: what, why, and how you tested it (which Windows version / client).
5. Keep PRs focused — one logical change each.

## License
By contributing, you agree your contributions are licensed under the project's [MIT License](LICENSE).

---

Maintained by **VZT Tech Consulting**. Be kind and constructive — assume good intent, keep discussions technical and respectful.
