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
  [string]$templateBaseUrl
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

$ErrorActionPreference = 'Continue'

$adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($adminPassword))

if ($vmAutologon -eq "true") {

  Write-Host "Configuring VM Autologon"

  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon" "1"
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUserName" $adminUsername
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultPassword" $adminPassword
  if($flavor -eq "DataOps"){
      Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultDomainName" "jumpstart.local"
  }
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

$ErrorActionPreference = 'Continue'

##############################################################
# Creating Ag paths
##############################################################
$paths = @("C:\Labs\", "C:\Labs\Tools\", "C:\Labs\Logs\", "C:\Labs\PowerShell\", "C:\Labs\Icons\")
Write-Output "Creating Ag paths"
foreach ($path in $paths) {
  Write-Output "Creating path $path"
  New-Item -ItemType Directory $path -Force
}

Start-Transcript -Path ("C:\Labs\Logs\Bootstrap.log")


##############################################################
# Copy PowerShell Profile and Reload
##############################################################
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/PSProfile.ps1") -OutFile "C:\Labs\PowerShell\Profile.ps1"
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
Invoke-WebRequest ($templateBaseUrl + "azure/PowerShell/LogonScript.ps1") -OutFile "C:\Labs\PowerShell\LogonScript.ps1"

##############################################################
# Disable Network Profile prompt
##############################################################
$RegistryPath = "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"
if (-not (Test-Path $RegistryPath)) {
  New-Item -Path $RegistryPath -Force | Out-Null
}

##############################################################
# Updating Microsoft Edge startup settings
##############################################################
# Disable Microsoft Edge sidebar
$Name = 'HubsSidebarEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $EdgeSettingRegistryPath)) {
  New-Item -Path $EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $EdgeSettingRegistryPath -Name $Name -Value $EdgeSettingValueFalse -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$Name = 'HideFirstRunExperience'
# Create the key if it does not exist
If (-NOT (Test-Path $EdgeSettingRegistryPath)) {
  New-Item -Path $EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $EdgeSettingRegistryPath -Name $Name -Value $EdgeSettingValueTrue -PropertyType DWORD -Force

# Disable Microsoft Edge "Personalize your web experience" prompt
$Name = 'PersonalizationReportingEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $EdgeSettingRegistryPath)) {
  New-Item -Path $EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $EdgeSettingRegistryPath -Name $Name -Value $EdgeSettingValueFalse -PropertyType DWORD -Force

# Show Favorites Bar in Microsoft Edge
$Name = 'FavoritesBarEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $EdgeSettingRegistryPath)) {
  New-Item -Path $EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $EdgeSettingRegistryPath -Name $Name -Value $EdgeSettingValueTrue -PropertyType DWORD -Force


$ScheduledTaskExecutable = "C:\Program Files\PowerShell\7\pwsh.exe"
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Action = New-ScheduledTaskAction -Execute "${ScheduledTaskExecutable}" -Argument "C:\Labs\PowerShell\LogonScript.ps1"
Register-ScheduledTask -TaskName "LogonScript" -User $adminUsername -Action $Action -RunLevel "Highest" -Force

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
