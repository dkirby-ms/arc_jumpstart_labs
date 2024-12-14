param (
  [string]$adminUsername,
  [string]$adminPassword,
  [string]$tenantId,
  [string]$subscriptionId,
  [string]$resourceGroup,
  [string]$azureLocation,
  [string]$aksClusterName,
  [string]$githubAccount,
  [string]$githubBranch,
  [string]$namingGuid,
  [string]$templateBaseUrl,
  [string]$vmAutologon
)

##############################################################
# Inject ARM template parameters as environment variables
##############################################################
[System.Environment]::SetEnvironmentVariable('adminUsername', $adminUsername, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('adminPassword', $adminPassword, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('tenantId', $tenantId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('resourceGroup', $resourceGroup, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('subscriptionId', $subscriptionId, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('azureLocation', $azureLocation, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('aksClusterName', $aksClusterName, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('templateBaseUrl', $templateBaseUrl, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubAccount', $githubAccount, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('githubBranch', $githubBranch, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('namingGuid', $namingGuid, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('vmAutologon', $vmAutologon, [System.EnvironmentVariableTarget]::Machine)

$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

if ($vmAutologon -eq "true") {

  Write-Host "Configuring VM Autologon"

  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" "1"
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUserName" $adminUsername
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" $adminPassword

} else {

  Write-Host "Not configuring VM Autologon"

}

$EdgeSettingRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$EdgeSettingValueTrue    = '00000001'
$EdgeSettingValueFalse   = '00000000'
##############################################################
# Extending C:\ partition to the maximum size
##############################################################
Write-Host "Extending C:\ partition to the maximum size"
Resize-Partition -DriveLetter C -Size $(Get-PartitionSupportedSize -DriveLetter C).SizeMax

##############################################################
# Download configuration data file and declaring directories
##############################################################
$ConfigurationDataFile = "C:\Temp\Config.psd1"
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/Config.psd1") -OutFile $ConfigurationDataFile
$Config = Import-PowerShellDataFile -Path $ConfigurationDataFile
[System.Environment]::SetEnvironmentVariable('ConfigPath', ($Config.Folders["PowerShellDir"] + "\Config.psd1"), [System.EnvironmentVariableTarget]::Machine)
Copy-Item $ConfigurationDataFile ($Config.Folders["PowerShellDir"] + "\Config.psd1") -Force

##############################################################
# Creating Ag paths
##############################################################
Write-Output "Creating paths"
foreach ($path in $Config.Folders.values) {
  Write-Output "Creating path $path"
  New-Item -ItemType Directory $path -Force
}

Start-Transcript -Path ($Config.Folders["LogsDir"] + "\Bootstrap.log")


##############################################################
# Copy PowerShell Profile and Reload
##############################################################
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/PSProfile.ps1") -OutFile ($Config.Folders["PowerShellDir"] + "\Profile.ps1")
.$PsHome\Profile.ps1

##############################################################
# Installing PowerShell 7
##############################################################
$ProgressPreference = 'SilentlyContinue'
$url = "https://github.com/PowerShell/PowerShell/releases/latest"
$latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $url).Content | Select-String -Pattern "v[0-9]+\.[0-9]+\.[0-9]+" | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
$downloadUrl = "https://github.com/PowerShell/PowerShell/releases/download/$latestVersion/PowerShell-$($latestVersion.Substring(1,5))-win-x64.msi"
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile .\PowerShell7.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I PowerShell7.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1'
Remove-Item .\PowerShell7.msi

Copy-Item $PsHome\Profile.ps1 -Destination "C:\Program Files\PowerShell\7\"

# Installing PowerShell Modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force
$modules = @("Az", "Az.ConnectedMachine", "Az.ConnectedKubernetes", "Az.CustomLocation", "Microsoft.PowerShell.SecretManagement", "Pester")

foreach ($module in $modules) {
    Install-PSResource -Name $module -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
}

##############################################################
# Download artifacts
##############################################################
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/LogonScript.ps1") -OutFile ($Config.Folders["PowerShellDir"] + "\LogonScript.ps1")




$ScheduledTaskExecutable = "C:\Program Files\PowerShell\7\pwsh.exe"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "${ScheduledTaskExecutable}" -Argument "C:\Labs\PowerShell\LogonScript.ps1"
Register-ScheduledTask -TaskName "LogonScript" -User $adminUsername -Trigger $Trigger -Action $Action -RunLevel "Highest" -Force

##############################################################
# Disabling Windows Server Manager Scheduled Task
##############################################################
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask

# Restart machine to initiate VM autologon
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-Command "Restart-Computer -Force"'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10))
$taskName = "Restart-Computer-Delayed"

# Define the restart action and schedule it to run after 10 seconds
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-Command "Restart-Computer -Force"'
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10))
# Configure the task to run with highest privileges and use the current user's credentials
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Principal $principal -Description "Restart computer after script exits"

Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content "C:\Labs\Logs\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "C:\Labs\Logs\Bootstrap.log" -Force
