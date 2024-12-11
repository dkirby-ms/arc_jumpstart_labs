@description('The name of your Virtual Machine')
param vmName string = 'Labs-VM-Client'

@description('Username for the Virtual Machine')
param windowsAdminUsername string = 'arcdemo'

@description('Password for Windows account. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. The value must be between 12 and 123 characters long')
@minLength(12)
@maxLength(123)
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version')
param windowsOSVersion string = '2022-datacenter-g2'

@description('The size of the virtual machine')
param vmSize string = 'Standard_B2s'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Labs'
}

@description('Resource Id of the subnet in the virtual network')
param subnetId string

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool = false

var bastionName = 'Labs-Bastion'
var publicIpAddressName = deployBastion == false ? '${vmName}-PIP' : '${bastionName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  name: networkInterfaceName
  location: location
  tags: resourceTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: deployBastion == false ? PublicIPNoBastion : null
        }
      }
    ]
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2023-02-01' = if (deployBastion == false) {
  name: publicIpAddressName
  location: location
  tags: resourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: resourceTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 256
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        enableVMAgentPlatformUpdates: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'Never'
          }
        }
      }
    }
  }
}

output adminUsername string = windowsAdminUsername
output publicIP string = deployBastion == false ? concat(publicIpAddress.properties.ipAddress) : ''
