<#
.SYNOPSIS
    Enterprise SOC Lab Endpoint Automation Script

.DESCRIPTION
    Automatically installs and configures:
    - Wazuh Agent
    - Sysmon
    - Sysmon Event Collection
    - File Integrity Monitoring (FIM)

    Designed for SOC Home Lab environments.

.NOTES
    File Name      : configure_agents.ps1
    Author         : Bommali Mallesh
    Version        : 2.0
    Created        : May 2026

.REQUIREMENTS
    - PowerShell 5.1+
    - Run as Administrator
    - Internet Connectivity
#>

# ==============================================================================
# 1. ENFORCE ADMINISTRATIVE PRIVILEGES
# ==============================================================================

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()

$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

$isAdmin = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[CRITICAL] Administrator privileges are required." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    Exit 1
}

# ==============================================================================
# 2. CONFIGURATION VARIABLES
# ==============================================================================

$WazuhManager   = "192.168.100.100"
$AgentName      = "WIN10-ENDPOINT"
$AgentGroup     = "Windows-Endpoints"

$WorkDir        = "C:\SOC_Agent_Setup"

$WazuhMsiUrl    = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.2-1.msi"
$WazuhMsiPath   = "$WorkDir\wazuh-agent.msi"

$SysmonZipUrl   = "https://download.sysinternals.com/files/Sysmon.zip"
$SysmonConfig   = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

$SysmonZipPath  = "$WorkDir\Sysmon.zip"
$SysmonConfigPath = "$WorkDir\sysmonconfig-export.xml"

$OssecConf      = "C:\Program Files (x86)\ossec-agent\ossec.conf"

# ==============================================================================
# 3. INITIALIZE ENVIRONMENT
# ==============================================================================

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "      SOC LAB ENDPOINT AUTOMATION INITIALIZATION         " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $WorkDir)) {
    New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null
}

# Force TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==============================================================================
# 4. DOWNLOAD WAZUH AGENT
# ==============================================================================

Write-Host "[1/6] Downloading Wazuh Agent..." -ForegroundColor Yellow

try {
    Invoke-WebRequest `
        -Uri $WazuhMsiUrl `
        -OutFile $WazuhMsiPath `
        -UseBasicParsing

    Write-Host "[SUCCESS] Wazuh Agent downloaded." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to download Wazuh Agent." -ForegroundColor Red
    Write-Host $_
    Exit 1
}

# ==============================================================================
# 5. INSTALL WAZUH AGENT
# ==============================================================================

Write-Host ""
Write-Host "[2/6] Installing Wazuh Agent..." -ForegroundColor Yellow

$MsiArgs = @(
    "/i"
    "`"$WazuhMsiPath`""
    "/qn"
    "WAZUH_MANAGER=`"$WazuhManager`""
    "WAZUH_AGENT_NAME=`"$AgentName`""
    "WAZUH_AGENT_GROUP=`"$AgentGroup`""
)

try {

    $Process = Start-Process `
        -FilePath "msiexec.exe" `
        -ArgumentList $MsiArgs `
        -Wait `
        -NoNewWindow `
        -PassThru

    if ($Process.ExitCode -eq 0) {
        Write-Host "[SUCCESS] Wazuh Agent installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] MSI Installation failed with code $($Process.ExitCode)" -ForegroundColor Red
        Exit 1
    }

}
catch {
    Write-Host "[ERROR] Failed to install Wazuh Agent." -ForegroundColor Red
    Write-Host $_
    Exit 1
}

# ==============================================================================
# 6. START WAZUH SERVICE
# ==============================================================================

Write-Host ""
Write-Host "[3/6] Starting Wazuh Service..." -ForegroundColor Yellow

try {

    Start-Service -Name "WazuhSvc"

    Start-Sleep -Seconds 5

    $svc = Get-Service -Name "WazuhSvc"

    if ($svc.Status -eq "Running") {
        Write-Host "[SUCCESS] Wazuh Service is running." -ForegroundColor Green
    }
    else {
        Write-Host "[ERROR] Wazuh Service failed to start." -ForegroundColor Red
    }

}
catch {
    Write-Host "[ERROR] Unable to start Wazuh Service." -ForegroundColor Red
}

# ==============================================================================
# 7. DOWNLOAD & INSTALL SYSMON
# ==============================================================================

Write-Host ""
Write-Host "[4/6] Installing Sysmon..." -ForegroundColor Yellow

try {

    Invoke-WebRequest `
        -Uri $SysmonZipUrl `
        -OutFile $SysmonZipPath `
        -UseBasicParsing

    Invoke-WebRequest `
        -Uri $SysmonConfig `
        -OutFile $SysmonConfigPath `
        -UseBasicParsing

    Expand-Archive `
        -Path $SysmonZipPath `
        -DestinationPath $WorkDir `
        -Force

    $SysmonExe = "$WorkDir\Sysmon64.exe"

    & $SysmonExe -accepteula -i $SysmonConfigPath

    Write-Host "[SUCCESS] Sysmon installed successfully." -ForegroundColor Green

}
catch {
    Write-Host "[ERROR] Sysmon installation failed." -ForegroundColor Red
    Write-Host $_
    Exit 1
}

# ==============================================================================
# 8. CONFIGURE SYSMON LOG COLLECTION
# ==============================================================================

Write-Host ""
Write-Host "[5/6] Configuring Sysmon Event Collection..." -ForegroundColor Yellow

if (Test-Path $OssecConf) {

    Copy-Item $OssecConf "$OssecConf.bak" -Force

    $conf = Get-Content $OssecConf -Raw

    if ($conf -notmatch "Microsoft-Windows-Sysmon/Operational") {

$SysmonBlock = @'

  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>

'@

        $UpdatedConf = $conf -replace '</ossec_config>', "$SysmonBlock</ossec_config>"

        Set-Content `
            -Path $OssecConf `
            -Value $UpdatedConf `
            -Force

        Write-Host "[SUCCESS] Sysmon localfile block added." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Sysmon block already exists." -ForegroundColor Cyan
    }

}
else {
    Write-Host "[ERROR] ossec.conf not found." -ForegroundColor Red
}

# ==============================================================================
# 9. CONFIGURE FILE INTEGRITY MONITORING (FIM)
# ==============================================================================

Write-Host ""
Write-Host "[6/6] Configuring File Integrity Monitoring..." -ForegroundColor Yellow

$FIMDirectory = "C:\FIM_Test"

if (-not (Test-Path $FIMDirectory)) {
    New-Item `
        -Path $FIMDirectory `
        -ItemType Directory `
        -Force | Out-Null
}

$conf = Get-Content $OssecConf -Raw

if ($conf -notmatch "C:\\FIM_Test") {

$FIMBlock = @'

  <syscheck>
    <disabled>no</disabled>
    <directories check_all="yes" realtime="yes">C:\FIM_Test</directories>
  </syscheck>

'@

    $UpdatedConf = $conf -replace '</ossec_config>', "$FIMBlock</ossec_config>"

    Set-Content `
        -Path $OssecConf `
        -Value $UpdatedConf `
        -Force

    Write-Host "[SUCCESS] FIM monitoring enabled." -ForegroundColor Green
}
else {
    Write-Host "[INFO] FIM configuration already exists." -ForegroundColor Cyan
}

# Restart Agent
Restart-Service -Name "WazuhSvc" -Force

# ==============================================================================
# 10. FINAL VERIFICATION
# ==============================================================================

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "                 FINAL VERIFICATION                      " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

$WazuhStatus = (Get-Service WazuhSvc).Status
$SysmonStatus = (Get-Service Sysmon64).Status

Write-Host "Wazuh Agent Status : $WazuhStatus" -ForegroundColor Green
Write-Host "Sysmon Status      : $SysmonStatus" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host " SOC ENDPOINT CONFIGURATION COMPLETED SUCCESSFULLY       " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Verify the endpoint in your Wazuh Dashboard:" -ForegroundColor Yellow
Write-Host "https://$WazuhManager" -ForegroundColor Cyan
Write-Host ""

# ==============================================================================
# 11. CLEANUP
# ==============================================================================

Write-Host "[*] Cleaning temporary installation files..." -ForegroundColor Yellow

try {
    Remove-Item `
        -Path $WorkDir `
        -Recurse `
        -Force

    Write-Host "[SUCCESS] Cleanup completed." -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Cleanup failed or directory already removed." -ForegroundColor Yellow
}