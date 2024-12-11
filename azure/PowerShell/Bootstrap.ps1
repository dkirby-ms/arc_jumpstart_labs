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
  [string]$namingGuid
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

##############################################################
# Download configuration data file and declaring directories
##############################################################

function BITSRequest {
  Param(
    [Parameter(Mandatory = $True)]
    [hashtable]$Params
  )
  $url = $Params['Uri']
  $filename = $Params['Filename']
  $download = Start-BitsTransfer -Source $url -Destination $filename -Asynchronous
  $ProgressPreference = "Continue"
  while ($download.JobState -ne "Transferred") {
    if ($download.JobState -eq "TransientError") {
      Get-BitsTransfer $download.name | Resume-BitsTransfer -Asynchronous
    }
    [int] $dlProgress = ($download.BytesTransferred / $download.BytesTotal) * 100;
    Write-Progress -Activity "Downloading File $filename..." -Status "$dlProgress% Complete:" -PercentComplete $dlProgress;
  }
  Complete-BitsTransfer $download.JobId
  Write-Progress -Activity "Downloading File $filename..." -Status "Ready" -Completed
  $ProgressPreference = "SilentlyContinue"
}

$ErrorActionPreference = 'Continue'


##############################################################
# Copy PowerShell Profile and Reload
##############################################################
Invoke-WebRequest ($templateBaseUrl + "azure/scripts/PSProfile.ps1") -OutFile $PsHome\Profile.ps1
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
#Invoke-WebRequest ($templateBaseUrl + "artifacts/PowerShell/Winget.ps1") -OutFile "$AgPowerShellDir\Winget.ps1"

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
