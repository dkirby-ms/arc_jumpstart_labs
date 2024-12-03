param location string = resourceGroup().location
param identityName string = 'myUserIdentity'

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output identityId string = userIdentity.id
output principalId string = userIdentity.properties.principalId
