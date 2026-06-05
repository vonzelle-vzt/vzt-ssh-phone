#Requires -Version 5.1
<#
.SYNOPSIS
  Health-check the vzt-ssh-phone setup and print the connection string.
.DESCRIPTION
  Read-only. Reports whether the SSH server, firewall, default shell, authorized keys,
  and Tailscale are all in place, then prints how to connect. Run anytime to confirm
  remote access is healthy (e.g. after a reboot or Windows update).
#>
function Line($label,$ok,$detail){
  $mark = if ($ok) { '[OK]' } else { '[!!]' }
  $col  = if ($ok) { 'Green' } else { 'Red' }
  Write-Host ("  {0,-4} {1,-22} {2}" -f $mark,$label,$detail) -ForegroundColor $col
}

Write-Host "`n=== vzt-ssh-phone : health check ===" -ForegroundColor White

$svc = Get-Service sshd -ErrorAction SilentlyContinue
Line 'sshd service' ($svc -and $svc.Status -eq 'Running') ($(if($svc){"$($svc.Status), $($svc.StartType)"}else{'not installed'}))

$listen = Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue
Line 'listening :22' ([bool]$listen) ($(if($listen){"$(($listen|Measure-Object).Count) listener(s)"}else{'nothing on :22'}))

$fw = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
Line 'firewall rule' ([bool]$fw -and $fw.Enabled -eq 'True') ($(if($fw){'enabled'}else{'missing'}))

$shell = (Get-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -ErrorAction SilentlyContinue).DefaultShell
Line 'default shell' ($shell -like '*powershell*') ($(if($shell){Split-Path $shell -Leaf}else{'default (cmd)'}))

# authorized_keys: admin file needs elevation to read; just report presence
$adminAkf = 'C:\ProgramData\ssh\administrators_authorized_keys'
$userAkf  = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
$keysFile = if (Test-Path $adminAkf) { $adminAkf } elseif (Test-Path $userAkf) { $userAkf } else { $null }
Line 'authorized_keys' ([bool]$keysFile) ($(if($keysFile){$keysFile}else{'no key authorized yet'}))

$tsExe = 'C:\Program Files\Tailscale\tailscale.exe'
$ip = $null
if (Test-Path $tsExe) {
  $ip = (& $tsExe ip -4 2>$null | Select-Object -First 1)
  Line 'tailscale' ([bool]$ip) ($(if($ip){"up @ $ip"}else{'installed, logged out (run: tailscale up)'}))
} else {
  Line 'tailscale' $false 'not installed'
}

if (-not $ip) {
  $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
         Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.*' } |
         Select-Object -First 1 -ExpandProperty IPAddress)
}

Write-Host "`n  Connect:  " -NoNewline
Write-Host "ssh $($env:USERNAME)@$ip" -ForegroundColor Cyan
Write-Host ""
