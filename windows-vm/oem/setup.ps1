# Runs once, at the end of the unattended install.
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
New-Item -Force 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' NoLockScreen 1 -Type DWord

New-NetFirewallRule -DisplayName 'voxl' -Direction Inbound -Protocol TCP -LocalPort 6911 -Action Allow | Out-Null
New-NetFirewallRule -DisplayName 'sshd' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null

Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Copy-Item 'C:\OEM\authorized_keys' 'C:\ProgramData\ssh\administrators_authorized_keys' -Force
icacls 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F'
New-ItemProperty 'HKLM:\SOFTWARE\OpenSSH' DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null
Set-Service sshd -StartupType Automatic
Start-Service sshd
