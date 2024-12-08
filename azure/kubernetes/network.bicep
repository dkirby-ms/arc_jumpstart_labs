param location string = resourceGroup().location
param vnetName string = 'aksVnet'
param subnetName string = 'aksSubnet'
param addressPrefix string = '10.0.0.0/16'
param subnetPrefix string = '10.0.0.0/24'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

output subnetId string = virtualNetwork.properties.subnets[0].id
