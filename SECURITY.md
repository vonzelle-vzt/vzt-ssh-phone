# Security Policy

`vzt-ssh-phone` configures **remote SSH access to a Windows PC**. Security is the whole point, so we take reports seriously.

## Supported versions
The latest release on `main` is supported. Please update before reporting.

| Version | Supported |
|---|---|
| latest (`main` / newest release) | ✅ |
| older tags | ❌ |

## Reporting a vulnerability
**Please do not open a public issue for security problems.**

Report privately via GitHub:
1. Go to the repo's **Security** tab → **Report a vulnerability** (this opens a private [security advisory](https://github.com/vonzelle-vzt/vzt-ssh-phone/security/advisories/new)).
2. Include: affected file/flag, Windows version, reproduction steps, and impact.

We aim to acknowledge within a few days and to fix or document confirmed issues promptly. Coordinated disclosure is appreciated — give us a chance to ship a fix before going public.

## What's in scope
- Flaws in the install/verify scripts that **weaken authentication or exposure** (e.g. wrong `authorized_keys` ACL, accidentally enabling password auth or public-internet exposure, leaking secrets).
- Supply-chain risks in how the scripts download/run components.

## What's *not* a vulnerability in this project
- **Your own deployment choices.** This tool defaults to Tailscale-only, key-based auth. If you port-forward SSH to the public internet, weaken the ACL, or share your private key, that's on the operator — see the [Security notes](README.md#security-notes) in the README.
- Issues in upstream projects (OpenSSH, Tailscale, Node.js, the AI CLIs) — report those to their respective maintainers.

## Operator responsibilities
You are responsible for securing access to your own machine: keep private keys on-device, prefer Tailscale over public exposure, revoke keys for lost devices (delete the line from `administrators_authorized_keys`), and keep Windows + OpenSSH + Tailscale updated.
