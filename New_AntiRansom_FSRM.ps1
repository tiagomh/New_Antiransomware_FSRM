# -----------------------------------------------------------------------------------------
# Powershell Script V2.0 Auto Install Anti-Rasomware FSRM 
# Company: REDCON - Soluções em T.I
# Author: Tiago Medeiros Hosang         
# Date: 26/04/2017
# Keywords: FSRM, ramsonware, schedule task, custom event log
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------#
# Step 1 : Check Powershell Version                                                        #
#------------------------------------------------------------------------------------------#

Write-Host "########################### STEP 1 #################################"  -ForegroundColor Cyan
Write-Host "Check Powershell Version"                                              -ForegroundColor Cyan                              
Write-Host "####################################################################"  -ForegroundColor Cyan
Start-Sleep -Seconds 5

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    Write-Host "PowerShell Version"$PSVersionTable.Psversion"" -foregroundcolor green

#------------------------------------------------------------------------------------------#
# Step 2: Verify if FSRM Resource Manager is installed, if not the script will install it. #
#------------------------------------------------------------------------------------------#

$feature = "*fs-resource-manager*"

Write-Host "########################### STEP 2 #################################" -ForegroundColor Cyan
Write-Host "Check File Server Resource Manager feature"                   -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan
Start-Sleep -Seconds 5

If (Get-WindowsFeature $feature | where-object InstallState -ne Installed){
    
    Get-WindowsFeature *FS-resource-manager* | Install-WindowsFeature -IncludeAllSubFeature -IncludeManagementTools
    Write-Host "File Server Resource Manager Feature was installed!!" -foreground Green

}else {
    Write-Host "File Server Resource Manager is already installed!" -foreground Yellow
    }

#------------------------------------------------------------------------------------------#
# Step 3: Check if FSRM Anti-Ransom File Gruop exist, if not the script will create it.
#------------------------------------------------------------------------------------------#

$filegroup = "Anti-Ransomware File Groups"

Write-Host "########################### STEP 3 #################################" -ForegroundColor Cyan
Write-Host "Check FSRM Anti-Ransom File Group"                                    -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan
Start-Sleep -Seconds 5

If (Get-fsrmfilegroup | where-object Name -eq "Anti-Ransomware File Groups"){
    
    Write-host "Anti-Ransomware File Groups already exists.." -ForegroundColor Yellow
    write-host "Updating File Group with new ransomware extensions...." -ForegroundColor Yellow

    set-FsrmFileGroup -name "Anti-Ransomware File Groups" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters})

}else {

    Write-host "Creating New FSRM Anti-Ransomware File Group..." -foreground Green

    new-FsrmFileGroup -name "Anti-Ransomware File Groups" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters})

    }

#---------------------------------------------------------------------------------------------#
# Step 4: Verify if FSRM Anti-Ransom File Screen Template exist, if not the script create it. #
#---------------------------------------------------------------------------------------------#

Write-Host "########################### STEP 4 #################################" -ForegroundColor Cyan
Write-Host "Check FSRM Anti-Ransom File File Screen Template"                     -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan

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
# Step 5: 5.1 - Script will ask the SMB physical path that you want to protect  
#         5.2 - Verify if FSRM Anti-Ransom File Screen exist, if not the script create it.
#---------------------------------------------------------------------------------------------#

# $Smbshare = "DADOS$"
# get-smbshare | Where-Object Name -eq $Smbshare | Select-Object Path
# Get-SmbShare | Where-Object Name -eq "DATA$" | Select-Object Path

Write-Host "########################### STEP 5 #################################" -ForegroundColor Cyan
Write-Host "5.1 - Check SMB physical paths"                                       -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan


Write-Host "Checking SMB Shares and Paths...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host "####################################################################" -ForegroundColor Magenta
write-host "Displaying File Shares and they related Physical Paths: See below!"   -ForegroundColor Magenta
Write-Host "####################################################################" -ForegroundColor Magenta
Get-SmbShare | Where-Object Path -notlike "C:\Windows*" | Where-Object Description -NotLike "Default*" |  Where-Object Description -NotLike "Remote*" | Select-Object Name,Path 


Start-Sleep -Seconds 5
Write-Host "####################################################################" -ForegroundColor Magenta
write-host "Displaying FSRM File Screens and Paths: See below!" -ForegroundColor Magenta
Write-Host "####################################################################" -ForegroundColor Magenta
Get-FsrmFileScreen | Where-Object Description -notlike "A" | Where-Object Path -NotLike "B" | Select-Object Description,Path


$Path = Read-Host "Please Type the Physical Path of the Shared Folder do you want protect against Ransomware"
Write-Host "$Path" -ForegroundColor Magenta

Write-Host "########################### STEP 5 #################################" -ForegroundColor Cyan
Write-Host "5.2 - Check FSRM Anti-Ransom File Screen"                               -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan

Write-Host "Checking FSRM File Screens...Wait a moment...." -ForegroundColor Cyan
Start-Sleep -Seconds 5

if ((Get-FsrmFileScreen | Where-Object Path -eq $Path) -and (Get-FsrmFileScreen | Where-Object Description -ne "Bloquear Ransomware")) {

    Write-Host "A File Screen named: 'Bloquear Ransomware' already exists on this path: $Path. Please choose another path!" -ForegroundColor Yellow
    
} else {

    New-FsrmFileScreen -Path $Path -Template "Bloquear Ransomware" -Description "Bloquear Ransomware"
    Write-Host "A File Screen named: Bloquear Ransomware was created on this path: $Path " -ForegroundColor Green
}

#-----------------------------------------------------------------------------------------------------------------------------------#
# Step 6: Verify if Task Schedule to update FSRM Anti-Ransom File Group exist, if not the script will import from xml and create it.
#-----------------------------------------------------------------------------------------------------------------------------------#

Write-Host "########################### STEP 6 #################################" -ForegroundColor Cyan
Write-Host "Check Task Schedule to update FSRM Anti-Ransom File Group           " -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan
Start-Sleep -Seconds 5

$UserName = whoami.exe
Write-Host "Type the password of the logged user $UserName" -ForegroundColor Yellow 
write-host "Be Carefull!!! The Password is visible and not encrypted!!!" -ForegroundColor Yellow
$password = Read-Host "PASSWORD"
Write-Host "Registering a Schedule Task to Update Anti-Ransom File Group" -ForegroundColor Yellow
Register-ScheduledTask -Xml (get-content 'C:\Util-Redcon\scripts\Update_Anti-Ransom_FSRM_FileGroup.xml' | out-string) -TaskName "Update_AntiRansom_FSRM_FileGroup" -User $UserName -Password $password –Force

#---------------------------------------------------------------------------------------------#
# Step 7: Import and Create a Custom View named Ransomware Log on Event Viewer.
#---------------------------------------------------------------------------------------------#

Write-Host "########################### STEP 7 #################################" -ForegroundColor Cyan
Write-Host "Importing a Custom View Ransomware log"                               -ForegroundColor Cyan                              
Write-Host "####################################################################" -ForegroundColor Cyan

Write-Host "Importing a Custom View Ransomware log to your server Event Viwer...Wait a moment...." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$run_eventviewer = "C:\Windows\system32\eventvwr.exe"
$CustomLog_path = "C:\Util-Redcon\Scripts\Ransomware_Log.xml"
&$run_eventviewer /v:$CustomLog_path

Start-Sleep -seconds 2 
Stop-Process -Name mmc
Write-Host "Closing Event Viwer...Wait a moment...." -ForegroundColor Yellow

#---------------------------------------------------------------------------------------------#
# Step 8: END Script
#---------------------------------------------------------------------------------------------#
    
    Start-Sleep -seconds 3 
    Write-Host "#################################### END #######################################" -ForegroundColor Cyan
    Write-Host "################################# THANK YOU ####################################" -ForegroundColor Cyan
    Start-Sleep -seconds 3
    Stop-Process -ProcessName powershell

}
else
{
    
#---------------------------------------------------------------------------------------------#
# Step 8: END Script if Powershell Version below 3.0 
#---------------------------------------------------------------------------------------------#

    Write-Host "CLOSING THE SCRIPT" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Write-Host "#################################### END #######################################" -ForegroundColor Cyan
    Write-Host "################################# THANK YOU ####################################" -ForegroundColor Cyan
    Start-Sleep -seconds 3
    Stop-Process -ProcessName powershell
}
