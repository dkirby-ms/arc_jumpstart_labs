param keyVaultId string
param userIdentityId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, userIdentityId, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Unique GUID for the role assignment
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets User role
    principalId: userIdentityId
  }
}
