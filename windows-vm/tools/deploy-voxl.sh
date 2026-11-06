#!/bin/zsh
# Installs a built voxl.exe in the guest and starts it in the console session.
#   tools/deploy-voxl.sh x64|arm64
set -eu
cd "${0:A:h}/.."
arch=$1
dir=vm/voxl-$arch
rm -rf "$dir"; mkdir -p "$dir"
run=$(gh run list -R hexuria/voxl --branch windows-exe --status success --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$run" -R hexuria/voxl -n "voxl-$arch" -D "$dir"
pw=$(cat vm/voxl.password)
cat > "$dir/start-voxl.ps1" <<PS
\$env:VOXL_PASSWORD = '$pw'
& 'C:\voxl-bin\voxl.exe' --addr=0.0.0.0 --port=6911 *> 'C:\voxl-bin\voxl.log'
PS
scpo=(-q -i ssh/id_ed25519 -P 2222 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
./ssh.sh 'Stop-ScheduledTask voxl -ErrorAction SilentlyContinue; Get-Process voxl -ErrorAction SilentlyContinue | Stop-Process -Force; New-Item -ItemType Directory -Force C:\voxl-bin | Out-Null'
scp $scpo "$dir/voxl.exe" "$dir/start-voxl.ps1" Docker@127.0.0.1:C:/voxl-bin/
./ssh.sh '
$a=New-ScheduledTaskAction -Execute conhost.exe -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\voxl-bin\start-voxl.ps1"
$t=New-ScheduledTaskTrigger -AtLogOn -User Docker
$p=New-ScheduledTaskPrincipal -UserId Docker -LogonType Interactive -RunLevel Highest
$s=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask voxl -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null
Start-ScheduledTask voxl
Start-Sleep 6
(Get-ScheduledTask voxl).State
Get-Process voxl -ErrorAction SilentlyContinue | ForEach-Object { "voxl pid=$($_.Id) session=$($_.SessionId) mem=$([int]($_.WorkingSet64/1MB))MB" }
Get-Content C:\voxl-bin\voxl.log -Tail 12 -ErrorAction SilentlyContinue
'
curl -s -m 8 -o /dev/null -w 'healthz=%{http_code}\n' http://127.0.0.1:6911/healthz
