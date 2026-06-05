#Requires -Version 5.1
<#
.SYNOPSIS
  Set up passwordless remote SSH into this Windows PC from your phone, tablet, or laptop over Tailscale.

.DESCRIPTION
  Installs and configures everything needed to SSH into this Windows machine from anywhere:
    1. OpenSSH server  - tries the built-in Windows capability; falls back to the standalone
                         Microsoft Win32-OpenSSH build if a pending reboot would hang DISM.
    2. sshd service    - started + set to auto-start on boot.
    3. Default shell   - PowerShell, so tools (claude, git, node) are on PATH over SSH.
    4. Firewall        - inbound TCP rule for the SSH port.
    5. Public key      - authorizes a key you generated on your CLIENT device (recommended).
    6. Tailscale       - installs + brings up a private mesh network so you can reach this PC
                         from anywhere without exposing it to the public internet.

  The script self-elevates via UAC (you approve one prompt).

.PARAMETER PublicKey
  An SSH public key LINE to authorize, e.g. "ssh-ed25519 AAAA... phone".
  BEST PRACTICE: generate the key on your client device (phone SSH app, or `ssh-keygen` on
  Mac/Linux) and pass only the PUBLIC half here. The private key never leaves your device.

.PARAMETER SkipTailscale
  Skip installing/starting Tailscale (e.g. you only need LAN access).

.PARAMETER Port
  SSH port. Default 22.

.EXAMPLE
  # Server-only setup (add your key afterward):
  irm https://raw.githubusercontent.com/vonzelle-vzt/vzt-ssh-phone/main/install.ps1 | iex

.EXAMPLE
  # Full setup with your phone's public key:
  .\install.ps1 -PublicKey "ssh-ed25519 AAAAC3NzaC1... phone"
#>
[CmdletBinding()]
param(
  [string]$PublicKey,
  [switch]$SkipTailscale,
  [int]$Port = 22
)

$ErrorActionPreference = 'Stop'
$BootstrapUrl = 'https://raw.githubusercontent.com/vonzelle-vzt/vzt-ssh-phone/main/install.ps1'

function Test-Admin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }
function Info($m){ Write-Host "    $m" -ForegroundColor Gray }
function Ok($m){   Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "    [!] $m" -ForegroundColor Yellow }

# ---------------------------------------------------------------- self-elevate
if (-not (Test-Admin)) {
  Step "Administrator rights required - relaunching (approve the UAC prompt)..."
  $a = @('-NoProfile','-ExecutionPolicy','Bypass')
  if ($PSCommandPath) {
    $a += @('-File', "`"$PSCommandPath`"")
    if ($PublicKey)    { $a += @('-PublicKey', "`"$PublicKey`"") }
    if ($SkipTailscale){ $a += '-SkipTailscale' }
    if ($Port -ne 22)  { $a += @('-Port', "$Port") }
  } else {
    # Running piped (irm | iex): re-bootstrap from the URL inside the elevated shell.
    $a += @('-Command', "irm $BootstrapUrl | iex")
  }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $a
  return
}

Write-Host "`n=== vzt-ssh-phone : remote SSH setup ===" -ForegroundColor White

# ---------------------------------------------------------------- 1. OpenSSH server
Step "OpenSSH server"
if (Get-Service sshd -ErrorAction SilentlyContinue) {
  Ok "sshd already installed"
} else {
  $installed = $false
  $rebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
  if ($rebootPending) {
    Warn "A system reboot is pending -> DISM would hang; using the standalone build."
  } else {
    try {
      Info "Trying the built-in Windows capability (DISM)..."
      $job = Start-Job { DISM /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0 | Out-Null }
      if (Wait-Job $job -Timeout 240) {
        Receive-Job $job | Out-Null
        if (Get-Service sshd -ErrorAction SilentlyContinue) { $installed = $true; Ok "Installed via Windows capability" }
      } else {
        Warn "Capability install timed out -> falling back to standalone build."
        Stop-Job $job -ErrorAction SilentlyContinue
        Get-Process dism,DismHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      }
      Remove-Job $job -Force -ErrorAction SilentlyContinue
    } catch { Warn "Capability install failed: $($_.Exception.Message)" }
  }

  if (-not $installed) {
    Info "Downloading standalone Win32-OpenSSH from GitHub..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ua  = @{ 'User-Agent' = 'vzt-ssh-phone' }
    $rel = Invoke-RestMethod 'https://api.github.com/repos/PowerShell/Win32-OpenSSH/releases/latest' -Headers $ua
    $asset = $rel.assets | Where-Object { $_.name -eq 'OpenSSH-Win64.zip' }
    $zip = Join-Path $env:TEMP 'OpenSSH-Win64.zip'
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip -Headers $ua
    $stage = Join-Path $env:TEMP 'OpenSSH-stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Expand-Archive $zip $stage -Force
    $srcDir = (Get-ChildItem $stage -Directory | Select-Object -First 1).FullName
    $dst = 'C:\Program Files\OpenSSH'
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item "$srcDir\*" $dst -Recurse -Force
    & "$dst\install-sshd.ps1"
    $p = [Environment]::GetEnvironmentVariable('Path','Machine')
    if ($p -notlike "*$dst*") { [Environment]::SetEnvironmentVariable('Path', "$p;$dst", 'Machine') }
    Remove-Item $zip,$stage -Recurse -Force -ErrorAction SilentlyContinue
    Ok "Installed standalone OpenSSH ($($rel.tag_name))"
  }
}
Set-Service sshd -StartupType Automatic
Start-Service sshd -ErrorAction SilentlyContinue
Ok "sshd running, auto-start on boot"

# ---------------------------------------------------------------- 2. default shell
Step "Default SSH shell -> PowerShell"
New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
  -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null
Ok "claude / git / node will resolve on PATH over SSH"

# ---------------------------------------------------------------- 3. firewall + port
Step "Firewall (TCP $Port)"
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port | Out-Null
  Ok "rule created"
} else { Ok "rule present" }
if ($Port -ne 22) {
  $cfg = 'C:\ProgramData\ssh\sshd_config'
  if (Test-Path $cfg) {
    (Get-Content $cfg) -replace '^#?Port\s+\d+', "Port $Port" | Set-Content $cfg
    Restart-Service sshd -ErrorAction SilentlyContinue
    Ok "sshd_config Port set to $Port"
  }
}

# ---------------------------------------------------------------- 4. authorize key
Step "Public key authorization"
if ($PublicKey) {
  $PublicKey = $PublicKey.Trim()
  $b64 = ($PublicKey -split '\s+')[1]
  $isAdminUser = [bool](Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -like "*\$env:USERNAME" })
  if ($isAdminUser) {
    # Admin accounts MUST use this file with a locked-down ACL, per Win32-OpenSSH.
    New-Item -ItemType Directory -Path 'C:\ProgramData\ssh' -Force | Out-Null
    $akf = 'C:\ProgramData\ssh\administrators_authorized_keys'
    $cur = if (Test-Path $akf) { Get-Content $akf -Raw } else { '' }
    if ($cur -notmatch [regex]::Escape($b64)) { Add-Content $akf $PublicKey -Encoding ascii; Ok "key added to administrators_authorized_keys" }
    else { Ok "key already authorized" }
    icacls $akf /inheritance:r              | Out-Null
    icacls $akf /grant 'SYSTEM:F'           | Out-Null
    icacls $akf /grant 'BUILTIN\Administrators:F' | Out-Null
    Ok "ACL locked to SYSTEM + Administrators (required for admin accounts)"
  } else {
    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    $akf = Join-Path $sshDir 'authorized_keys'
    $cur = if (Test-Path $akf) { Get-Content $akf -Raw } else { '' }
    if ($cur -notmatch [regex]::Escape($b64)) { Add-Content $akf $PublicKey -Encoding ascii; Ok "key added to $akf" }
    else { Ok "key already authorized" }
    icacls $akf /inheritance:r | Out-Null
    icacls $akf /grant "$($env:USERNAME):F" | Out-Null
    Ok "ACL set (owner only)"
  }
} else {
  Warn "No -PublicKey supplied. Server is ready, but you still need to authorize a key:"
  Warn "  1. On your CLIENT device, generate an SSH key (phone app, or 'ssh-keygen -t ed25519' on Mac/Linux)."
  Warn "  2. Re-run:  .\install.ps1 -PublicKey `"ssh-ed25519 AAAA... yourdevice`""
}

# ---------------------------------------------------------------- 5. Tailscale
$tsExe = 'C:\Program Files\Tailscale\tailscale.exe'
if (-not $SkipTailscale) {
  Step "Tailscale (private network)"
  if (-not (Test-Path $tsExe)) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Info "Installing via winget..."
      winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements | Out-Null
    } else {
      Info "winget not found - downloading the Tailscale installer..."
      $ts = Join-Path $env:TEMP 'tailscale-setup.exe'
      Invoke-WebRequest 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe' -OutFile $ts
      Start-Process $ts -ArgumentList '/quiet' -Wait
    }
    Ok "Tailscale installed"
  } else { Ok "Tailscale already installed" }

  if (Test-Path $tsExe) {
    Step "Logging into Tailscale (a browser window will open - sign in)..."
    & $tsExe up
    Start-Sleep -Seconds 2
    $ip = (& $tsExe ip -4 2>$null | Select-Object -First 1)
  }
}

# ---------------------------------------------------------------- summary
$ip = if ($ip) { $ip } else { (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.*' } |
        Select-Object -First 1 -ExpandProperty IPAddress) }

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " DONE - SSH server is live" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Connect from any device on the same Tailscale network:" -ForegroundColor White
Write-Host ""
Write-Host "      ssh $($env:USERNAME)@$ip" -ForegroundColor Cyan
Write-Host ""
$authState = if ($PublicKey) { 'SSH key (authorized)' } else { 'SSH key (add one with -PublicKey)' }
Write-Host "  Username : $($env:USERNAME)"
Write-Host "  Address  : $ip   (Port $Port)"
Write-Host "  Auth     : $authState"
Write-Host "  After a reboot: nothing to do - sshd + Tailscale auto-start."
Write-Host "  See README for iPhone / Android / Mac client steps."
Write-Host ""
