# -----------------------------------------------------------------------------------------
# Powershell Script V1.5 Auto Install Anti-Rasomware FSRM 
# Company: REDCON - Soluções em T.I
# Author: Tiago Medeiros Hosang         
# Date: 26/04/2017
# Keywords: FSRM, ramsonware, schedule task, custom event log
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------#
# 1 - Part: Verify if FSRM Resource Manager is installed, if not the script will do this.  #
#------------------------------------------------------------------------------------------#

$feature = "*fs-resource-manager*"

Write-Host "################################### STEP 1 ######################################" -ForegroundColor Cyan
Write-Host "Checking File Server Resource Manager feature...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

If (Get-WindowsFeature $feature | where-object InstallState -ne Installed){
    
    Write-Host "File Server Resource Manager Feature installed!!" -foreground Green

    Get-WindowsFeature *FS-resource-manager* | Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools
}else {
    Write-Host "File Server Resource Manager is already installed!" -foreground Yellow
    }

#------------------------------------------------------------------------------------------#
# 2 - Part: Verify if FSRM Anti-Ransom File Gruop exist, if not the script create it.
#------------------------------------------------------------------------------------------#

$filegroup = "Anti-Ransomware File Groups"

Write-Host "################################### STEP 2 ######################################" -ForegroundColor Cyan
Write-Host "Checking FSRM Anti-Ransomware File Groups...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

If (Get-fsrmfilegroup | where-object Name -eq "Anti-Ransomware File Groups"){
    
    Write-host "Anti-Ransomware File Groups already exists...Updating File Group with new extensions...." -foreground Yellow

    set-FsrmFileGroup -name "Anti-Ransomware File Groups" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters})

}else {

    Write-host "Creating New FSRM Anti-Ransomware File Group..." -foreground Green

    new-FsrmFileGroup -name "Anti-Ransomware File Groups" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters})

    }

#---------------------------------------------------------------------------------------------#
# 3 - Part: Verify if FSRM Anti-Ransom File Screen Template exist, if not the script create it.
#---------------------------------------------------------------------------------------------#

Write-Host "################################### STEP 3 ######################################" -ForegroundColor Cyan
Write-Host "Checking FSRM Anti-Ransomware File Screen Template...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$Notification1 = New-FsrmAction -Type Event -EventType Information -Body "O usuário [Source Io Owner] tentou salvar [Source File Path] em [File Screen Path] no servidor [Server]. Esse arquivo está no grupo de arquivos [Violated File Group], que não é permitido no servidor." 

if (Get-FsrmFileScreenTemplate | Where-Object Name -Like "Bloquear Ransomware") {

    Set-FsrmFileScreenTemplate -Name "Bloquear Ransomware" -IncludeGroup "Anti-Ransomware File Groups" -Active -Notification $Notification1 | Out-Null
    
    Write-Host "Updated File Screen Template! Name: Bloquear Ransomware" -ForegroundColor Yellow
    
} else {

    New-FsrmFileScreenTemplate -Name "Bloquear Ransomware" –IncludeGroup "Anti-Ransomware File Groups" -Notification $Notification1 -Active -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Created File Screen Template! Name: Bloquear Ransomware" -ForegroundColor Green
}


#---------------------------------------------------------------------------------------------#
# 4 - Part: 4.1 - First the Script will ask the SMB File physical path
#           4.2 - Verify if FSRM Anti-Ransom File Screen exist, if not the script create it.
#---------------------------------------------------------------------------------------------#

# $Smbshare = "DADOS$"
# get-smbshare | Where-Object Name -eq $Smbshare | Select-Object Path
# Get-SmbShare | Where-Object Name -eq "DADOS$" | Select-Object Path

Write-Host "################################### STEP 4 ######################################" -ForegroundColor Cyan
Write-Host "Checking SMB Shares and Paths...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

write-host "Displaying SMB Shares and related Physical Paths: See below!" -ForegroundColor Magenta
Get-SmbShare | Where-Object Path -notlike "C:\Windows*" | Where-Object Description -NotLike "Default*" |  Where-Object Description -NotLike "Remote*" | Select-Object Name,Path 

Start-Sleep -Seconds 5
write-host "Displaying FSRM File Screens and Paths: See below!" -ForegroundColor Magenta
Get-FsrmFileScreen | Where-Object Description -notlike "A" | Where-Object Path -NotLike "B" | Select-Object Description,Path


$Path = Read-Host "Please Type the Physical Path of the Shared Folder do you want protect against Ransomware"
Write-Host "$Path" -ForegroundColor Magenta

Write-Host "Checking FSRM File Screens...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

if ((Get-FsrmFileScreen | Where-Object Path -eq $Path) -and (Get-FsrmFileScreen | Where-Object Description -ne "Bloquear Ransomware")) {

    Write-Host "A File Screen named: Bloquear Ransomware already exists on this path: $Path. Please choose another path!" -ForegroundColor Yellow
    
} else {

    New-FsrmFileScreen -Path $Path -Template "Bloquear Ransomware" -Description "Bloquear Ransomware"
    Write-Host "A File Screen named: Bloquear Ransomware was created on this path: $Path " -ForegroundColor Green
}

#---------------------------------------------------------------------------------------------#
# 5 - Part: Verify if Task Schedule to update FSRM Anti-Ransom File Group exist, if not the script create it.
#---------------------------------------------------------------------------------------------#

## $SecurePassword = $password = Read-Host -AsSecureString
## $UserName = "svc_account"
## $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecurePassword
## $Password = $Credentials.GetNetworkCredential().Password

## Register-ScheduledTask -Xml (get-content 'C:\Util-Redcon\scripts\Update_AntiRansom_FSRM.ps1' | out-string) -TaskName "Update_AntiRansom_FSRM_FileGroup" -User globomantics\administrator -Password P@ssw0rd –Force

#---------------------------------------------------------------------------------------------#
# 6 - Part: Import and Create a Custom View named Ransomware Log on Event Viewer.
#---------------------------------------------------------------------------------------------#

# &$run_eventviewer /v:"C:\Util-Redcon\Scripts\Ransomware_Log.xml"

Write-Host "################################### STEP 6 ######################################" -ForegroundColor Cyan
Write-Host "Importing a Custom View Ransomware log to your server Event Viwer...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$run_eventviewer = "C:\Windows\system32\eventvwr.exe"
$CustomLog_path = "C:\Util-Redcon\Scripts\Ransomware_Log.xml"
&$run_eventviewer /v:$CustomLog_path

Start-Sleep -seconds 2 
Stop-Process -Name mmc
Write-Host "Closing Event Viwer...Wait a moment...." -ForegroundColor Yellow

#---------------------------------------------------------------------------------------------#
# 7 - Part: END Script
#---------------------------------------------------------------------------------------------#

Write-Host "#################################### END #######################################" -ForegroundColor Cyan
Write-Host "################################# Thank You! ###################################" -ForegroundColor Cyan