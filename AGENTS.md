# AGENTS.md — agent takeover playbook for vzt-ssh-phone

**Audience: an AI coding agent (Claude Code, OpenAI Codex, Gemini CLI, etc.) running in a terminal on the user's Windows PC.** This file tells you how to *take over* and set up remote phone→PC SSH for the user with the least possible effort on their part — drive it yourself, headless, and only hand back the few steps a human physically must do.

## Goal
Get the user able to `ssh <user>@<tailscale-ip>` from their phone and run a CLI (you). Install the SSH server + Tailscale + (optionally) the AI CLIs, authorize the user's device key, and verify — bundling everything so the user interacts the absolute minimum.

## The 3 things only a human can do (everything else is yours)
1. **Approve the UAC elevation prompt** (once). It renders on the secure desktop — no software can click it.
2. **Sign into Tailscale** in the browser window that opens (once).
3. **Sign into each AI CLI** in the browser the first time (once, locally) — first-run auth opens on the PC, not the phone.

Plan around these: do everything else automatically, and tell the user clearly when each click is needed.

## Procedure

### 1. Get the repo
If not already present, clone or download it, then `cd` into it:
```powershell
git clone https://github.com/vonzelle-vzt/vzt-ssh-phone
cd vzt-ssh-phone
```

### 2. Get the user's device public key (recommended)
Ask the user to generate a key **on the device they'll connect from** and paste the **public** line:
- Phone SSH app (Termius/Blink): *Generate Key → ED25519* → copy public key.
- Mac/Linux: `ssh-keygen -t ed25519` then `cat ~/.ssh/id_ed25519.pub`.

Never ask for a private key. If they can't do this yet, run the install without `-PublicKey` and authorize the key later (re-run with `-PublicKey`).

### 3. Launch the installer ELEVATED and headless, with a status file you poll
Pick an **absolute** status path (the elevated child runs from `system32`, so relative paths won't resolve). Choose the CLI(s) to install — typically include the one you are.

```powershell
$status = "$env:USERPROFILE\vzt-ssh-status.jsonl"
Remove-Item "$status.done" -ErrorAction SilentlyContinue
Start-Process powershell -Verb RunAs -ArgumentList @(
  '-NoProfile','-ExecutionPolicy','Bypass',
  '-File', (Resolve-Path .\install.ps1).Path,
  '-PublicKey', '<ssh-ed25519 AAAA... device>',
  '-InstallClis', 'all',          # or 'claude' / 'codex' / 'gemini' / 'claude,codex'
  '-StatusFile', $status
)
```
**Tell the user: "Approve the UAC prompt now."** The non-elevated launch returns immediately; the elevated child does the work and writes `$status` (JSONL progress) + `$status.done` when finished.

### 4. Poll for completion, then report
```powershell
$status = "$env:USERPROFILE\vzt-ssh-status.jsonl"
while (-not (Test-Path "$status.done")) { Start-Sleep -Seconds 3 }
Get-Content $status            # JSONL: {"phase":...,"state":"progress|warn|success","msg":...}
Get-Content "$status.done"     # the final "ssh <user>@<ip>" connection string
```
Surface any `"state":"warn"` lines to the user. The OpenSSH install can take a few minutes the first time (it may fall back to the standalone build); keep polling.

### 5. Tailscale login
When the installer reaches the Tailscale phase it runs `tailscale up`, which opens a browser. **Tell the user to sign in** (same account they'll use on the phone). If it was already logged in, nothing is needed.

### 6. Verify and hand off
```powershell
powershell -ExecutionPolicy Bypass -File .\verify.ps1
```
Report the printed `ssh <user>@<tailscale-ip>` line. Then tell the user:
- Install **Tailscale** on the phone, sign into the **same account**, toggle ON.
- In their SSH app, set the host to that IP, user, and **their key**, and connect.
- If they want to run you (the CLI) from the phone: it's installed; they must **sign in once locally at the PC** (browser auth), after which `claude` / `codex` / `gemini` work over SSH.

## Known gotchas (handle proactively)
- **Admin account keys** must go in `C:\ProgramData\ssh\administrators_authorized_keys` (ACL: SYSTEM + Administrators), NOT `~\.ssh\authorized_keys`. The installer does this; if you ever do it by hand, fix the ACL or auth silently fails with `Permission denied (publickey,...)`.
- **Microsoft-account PCs**: the sign-in **PIN is not the account password** and the password is online-managed (can't `net user`-reset; returns *error 8646*). Don't try to fix login with a password — use the key (above).
- **Pending reboot** makes the built-in `Add-WindowsCapability`/DISM install hang at ~0% CPU. The installer detects this and uses the standalone OpenSSH build automatically — don't kill it prematurely; poll the status file.
- **`tailscale up` over an existing SSH session**: never run `--force-reauth` remotely (can drop the link). Plain `tailscale up` is fine.
- **CLI sign-in cannot be automated** (browser OAuth). Installing the CLI is automatic; authenticating it is a one-time local human step — say so.

## Idempotency
`install.ps1` is safe to re-run: it skips what's done and adds what's missing (e.g. authorizing another device's key, or installing a CLI you didn't include the first time).
