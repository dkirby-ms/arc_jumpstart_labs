param location string = resourceGroup().location
param keyVaultName string = 'kv-jslabs'

resource keyVault 'Microsoft.KeyVault/vaults@2022-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    // Enable Azure RBAC
    enableRbacAuthorization: true
  }
}

output keyVaultId string = keyVault.id
