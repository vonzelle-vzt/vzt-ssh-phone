# Rollback plan

`vzt-ssh-phone` is not a deployed service: there is no Vercel project, mobile app, or database, so there are no deployments to promote, OTA updates to halt, or migrations to revert. "Rolling back" means either **undoing what `install.ps1` changed on a PC** or **reverting a bad change to this repo**. Both are below.

## 1. Undo an install on a PC

Run in an elevated PowerShell. Every step is safe to skip if that part was never installed.

Full removal is documented in the README [Uninstall](../README.md#uninstall) section. To roll back individual changes instead:

| `install.ps1` change | Undo |
|---|---|
| OpenSSH server (capability or standalone build) | `Stop-Service sshd`, then `& 'C:\Program Files\OpenSSH\uninstall-sshd.ps1'` (standalone) or `Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` (capability) |
| sshd auto-start | `Set-Service sshd -StartupType Manual` (or `Disabled`) and `Stop-Service sshd` |
| Default SSH shell (`HKLM:\SOFTWARE\OpenSSH\DefaultShell`) | `Remove-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell` |
| Firewall rule `OpenSSH-Server-In-TCP` | `Remove-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'` |
| Custom `Port` in `C:\ProgramData\ssh\sshd_config` | Set the line back to `#Port 22` (or `Port 22`), then `Restart-Service sshd` |
| Authorized key | Delete that device's line from `C:\ProgramData\ssh\administrators_authorized_keys` (admin accounts) or `~\.ssh\authorized_keys` (others). To revoke access immediately, do this first. |
| Tailscale | `winget uninstall Tailscale.Tailscale`, or remove the device from the Tailscale admin console |
| AI CLIs | `npm uninstall -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli` (only those you installed) |
| Machine `PATH` entry added by the standalone OpenSSH build | Remove the OpenSSH directory from the Machine `Path` environment variable |

**Fastest lockout** if a key is compromised or something misbehaves: `Stop-Service sshd; Set-Service sshd -StartupType Disabled`. Nothing is exposed publicly (access is via Tailscale), so this closes remote access completely.

Check the result with `verify.ps1`; it should report the removed pieces as missing.

## 2. Revert a bad change to this repo

Changes reach `main` only through pull requests.

1. Find the merge commit: `git log --oneline main`.
2. Revert it on a branch: `git revert -m 1 <merge-sha>` (for a squash merge, plain `git revert <sha>`).
3. Open a PR with the revert and merge it once CI passes.

Users who cloned the repo pick up the revert with `git pull`. Re-running `install.ps1` is idempotent, so a corrected script can simply be run again over a previous install.

## 3. Database migrations

None. This repo has no database or migrations.
