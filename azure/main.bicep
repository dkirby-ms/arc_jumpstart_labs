param location string = resourceGroup().location
param clusterName string = 'aks-jslabs'
param nodeCount int = 1
param minCount int = 1
param maxCount int = 3
param nodeSize string = 'Standard_B2s'
param keyVaultName string = 'kv-jslabs'
param identityName string = 'id-jslabs'
param registryName string = 'crjslabs'

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

module keyVaultModule 'operations/keyvault.bicep' = {
  name: 'deployKeyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
    aksClusterId: aksModule.outputs.aksClusterPrincipalId
    userIdentityPrincipalId: userIdentityModule.outputs.principalId
  }
}
