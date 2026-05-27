# Active Directory Domain Controller Promotion Automation Script
# Automated Active Directory Forest Installation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please rerun this PowerShell window as Administrator!"
    Exit
}

Write-Output "[*] Installing Active Directory Domain Services Role..."
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Output "[*] Deploying New Forest: soclab.local..."
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "WinThreshold" `
    -DomainName "soclab.local" `
    -DomainNetbiosName "SOCLAB" `
    -ForestMode "WinThreshold" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true