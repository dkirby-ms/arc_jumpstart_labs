@{
    # Folder paths
    Folders           = @{
        Dir             = "C:\Labs"
        PowerShellDir   = "C:\Labs\PowerShell"
        LogsDir         = "C:\Labs\Logs"
        IconDir         = "C:\Labs\Icons"
        TestsDir        = "C:\Labs\Tests"
        ToolsDir        = "C:\Labs\Tools"
        TempDir         = "C:\Temp"
    }

    $packages = @(
    'Microsoft.AzureCLI',
    'Microsoft.PowerShell',
    'Microsoft.Bicep',
    'Kubernetes.kubectl',
    'Microsoft.Edge',
    'Microsoft.Azure.AZCopy.10',
    'Microsoft.VisualStudioCode',
    'Git.Git',
    'Helm.Helm',
    'Derailed.K9s'
    )

    AzCLIExtensions = @(
        @{name="k8s-extension"; version="latest"},
        @{name="k8s-configuration"; version="latest"},
        @{name="customlocation"; version="latest"},
        @{name="kusto"; version="latest"}
    )

    PowerShellModules = @(
        @{name='Az.ConnectedKubernetes'; version="latest"},
        @{name='Az.KubernetesConfiguration'; version="latest"},
        @{name='Az.Kusto'; version="latest"},
        @{name='Az.EventGrid'; version="latest"},
        @{name='Az.Storage'; version="latest"},
        @{name='Az.EventHub'; version="latest"},
        @{name='powershell-yaml'; version="latest"}
    )

    # Microsoft Edge startup settings variables
    EdgeSettingRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    EdgeSettingValueTrue    = '00000001'
    EdgeSettingValueFalse   = '00000000'
}