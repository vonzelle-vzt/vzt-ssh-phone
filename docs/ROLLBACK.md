# Rollback

`vzt-ssh-phone` is a set of PowerShell scripts, not a deployed service: there is no
Vercel project, mobile app, OTA channel, or database, so there are no migrations to
revert. "Rolling back" means either (a) going back to a previous version of the scripts,
or (b) undoing what `install.ps1` changed on the host. `install.ps1` is idempotent, so
re-running it is always safe.

## 1. Roll back the scripts

Run a previous known-good revision instead of `main`:

```powershell
git fetch --tags
git checkout <previous-tag-or-commit>
.\install.ps1 -PublicKey "<your public key>"
```

To undo a bad change on `main`, open a PR that runs `git revert <sha>`; do not force-push.

## 2. Undo host changes made by `install.ps1`

Run in an **elevated** PowerShell. Each step is independent; do only the ones you need.

| Installer step | Undo |
|---|---|
| Key authorization | Delete the device's line from `C:\ProgramData\ssh\administrators_authorized_keys` (admin accounts) or `~\.ssh\authorized_keys`. No `sshd` restart needed. |
| Custom `-Port` | Edit `Port` in `C:\ProgramData\ssh\sshd_config` back to `22`, `Restart-Service sshd`, and update the firewall rule's `LocalPort` (`Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -LocalPort 22`). |
| Firewall rule | `Remove-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'` |
| SSH server stopped working | `Restart-Service sshd`; if it still fails, re-run `install.ps1` to repair. |
| Stop remote access immediately | `Stop-Service sshd; Set-Service sshd -StartupType Disabled` (re-enable with `Set-Service sshd -StartupType Automatic; Start-Service sshd`). |
| Tailscale | `tailscale down`, or `winget uninstall Tailscale.Tailscale`. |
| AI CLIs (`-InstallClis`) | `npm uninstall -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli` |

For a full removal of OpenSSH, see [Uninstall](../README.md#uninstall) in the README.

## 3. Verify

```powershell
.\verify.ps1
```
