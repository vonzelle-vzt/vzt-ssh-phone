# CLAUDE.md

You are running as an agent in this repo. To set up remote phone→PC SSH for the user
(taking over the terminal and minimizing their effort), follow **[AGENTS.md](AGENTS.md)**.

TL;DR: launch `install.ps1` elevated with `-PublicKey`, `-InstallClis`, and an absolute
`-StatusFile`; tell the user to approve the single UAC prompt; poll `<StatusFile>.done`;
then run `verify.ps1` and report the `ssh <user>@<ip>` string. The only human steps are
the UAC click, the Tailscale browser login, and a one-time local CLI sign-in.
