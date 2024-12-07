param location string = resourceGroup().location
param clusterName string = 'aks-jslabs'
param nodeCount int = 1
param minCount int = 1
param maxCount int = 3
param nodeSize string = 'Standard_D4s_v5'
param keyVaultName string = 'kv-jslabs'
param identityName string = 'id-jslabs'
param registryName string = 'crjslabs'

module keyVaultModule 'operations/keyvault.bicep' = {
  name: 'deployKeyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
  }
}

module userIdentityModule 'operations/userIdentity.bicep' = {
  name: 'deployUserIdentity'
  params: {
    location: location
    identityName: identityName
  }
}

module containerRegistryModule 'operations/containerRegistry.bicep' = {
  name: 'deployContainerRegistry'
  params: {
    location: location
    registryName: registryName
    userIdentityPrincipalId: userIdentityModule.outputs.principalId
  }
}

module aksModule 'kubernetes/aks.bicep' = {
  name: 'deployAksCluster'
  params: {
    location: location
    clusterName: clusterName
    nodeCount: nodeCount
    minCount: minCount
    maxCount: maxCount
    nodeSize: nodeSize
    userIdentityId: userIdentityModule.outputs.identityId
  }
}

module roleAssignment 'operations/roleAssignments.bicep' = {
  name: 'roleAssignment'
  params: {
    keyVaultId: keyVaultModule.outputs.keyVaultId
    userIdentityId: userIdentityModule.outputs.principalId
  }
}

