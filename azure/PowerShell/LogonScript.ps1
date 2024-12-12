# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

$ProgressPreference = "SilentlyContinue"
Set-PSDebug -Strict

#####################################################################
# Initialize the environment
#####################################################################
$global:ToolsDir = $AgConfig.AgDirectories["AgToolsDir"]
$global:IconsDir = $AgConfig.AgDirectories["AgIconDir"]
$global:PowerShellDir    = $AgConfig.AgDirectories["AgPowerShellDir"]
$global:LogsDir = $AgConfig.AgDirectories["AgLogsDir"]
$global:githubAccount = $Env:githubAccount
$global:githubBranch = $Env:githubBranch
$global:resourceGroup = $Env:resourceGroup
$global:azureLocation = $Env:azureLocation
$global:spnTenantId = $Env:spnTenantId
$global:subscriptionId = $Env:subscriptionId
$global:adminUsername = $Env:adminUsername
$global:templateBaseUrl = $Env:templateBaseUrl
$global:namingGuid = $Env:namingGuid
$global:adminPassword = $Env:adminPassword

Start-Transcript -Path ("C:\Labs\Logs\LogonScript.log")
Write-Host "Executing Jumpstart Labs automation scripts"
$startTime = Get-Date

## Winget
Install-PSResource -Name Microsoft.WinGet.Client -Scope AllUsers -Quiet -AcceptLicense -TrustRepository
$null = Repair-WinGetPackageManager -AllUsers -Force -Latest
$winget = Join-Path -Path $env:LOCALAPPDATA -ChildPath Microsoft\WindowsApps\winget.exe
& $winget install Microsoft.WindowsTerminal --version 1.18.3181.0 -s winget --silent --accept-package-agreements
##############################################################
# Install Winget packages
##############################################################
$packages = @(
  'Microsoft.AzureCLI',
  'Microsoft.PowerShell',
  'Microsoft.Bicep',
  'Kubernetes.kubectl',
  'Microsoft.Edge',
  'Microsoft.Azure.AZCopy.10',
  'Microsoft.VisualStudioCode'
)
$maxRetries = 3
$retryDelay = 30  # seconds

$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    Write-Host "Winget packages specified"

    try {
        foreach ($app in $packages) {
            Write-Host "Installing $app"
            & $winget install -e --id $app --silent --accept-package-agreements --accept-source-agreements --ignore-warnings
        }

        # If the command succeeds, set $success to $true to exit the loop
        $success = $true
    }
    catch {
        # If an exception occurs, increment the retry count
        $retryCount++

        # If the maximum number of retries is not reached yet, display an error message
        if ($retryCount -lt $maxRetries) {
            Write-Host "Attempt $retryCount failed. Retrying in $retryDelay seconds..."
            Start-Sleep -Seconds $retryDelay
        }
        else {
            Write-Host "All attempts failed. Exiting..."
            exit 1  # Stop script execution if maximum retries reached
        }
    }
}

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
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueFalse -PropertyType DWORD -Force

# Disable Microsoft Edge first-run Welcome screen
$Name = 'HideFirstRunExperience'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueTrue -PropertyType DWORD -Force

# Disable Microsoft Edge "Personalize your web experience" prompt
$Name = 'PersonalizationReportingEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueFalse -PropertyType DWORD -Force

# Show Favorites Bar in Microsoft Edge
$Name = 'FavoritesBarEnabled'
# Create the key if it does not exist
If (-NOT (Test-Path $AgConfig.EdgeSettingRegistryPath)) {
  New-Item -Path $AgConfig.EdgeSettingRegistryPath -Force | Out-Null
}
New-ItemProperty -Path $AgConfig.EdgeSettingRegistryPath -Name $Name -Value $AgConfig.EdgeSettingValueTrue -PropertyType DWORD -Force

##############################################################
# Installing Posh-SSH PowerShell Module
##############################################################
Install-Module -Name Posh-SSH -Force

##############################################################
# Disabling Windows Server Manager Scheduled Task
##############################################################
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask


Stop-Transcript

##############################################################
# Clean up Bootstrap.log
##############################################################
Write-Host "Clean up Bootstrap.log"
Stop-Transcript
$logSuppress = Get-Content "$AgDirectory\Bootstrap.log" | Where-Object { $_ -notmatch "Host Application: powershell.exe" }
$logSuppress | Set-Content "$AgDirectory\Bootstrap.log" -Force
