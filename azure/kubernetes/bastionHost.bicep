param adminUsername string
param sshPublicKey string
param computerName string
param vmSize string = 'Standard_B1s'

resource bastionHost 'Microsoft.Network/bastionHosts@2020-05-01' = {
  name: 'myBastionHost'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionHostIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'myVnet', 'mySubnet')
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', 'myPublicIP')
          }
        }
      }
    ]
  }
}

resource jumpboxVM 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: 'myJumpboxVM'
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', 'myJumpboxVMNic')
        }
      ]
    }
  }
}
