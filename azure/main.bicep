param location string = resourceGroup().location
param clusterName string = 'aks-jslabs'
param nodeCount int = 1
param minCount int = 1
param maxCount int = 3
param nodeSize string = 'Standard_D4s_v5'
param keyVaultName string = 'kv-jslabs'
param identityName string = 'id-jslabs'
param registryName string = 'crjslabs'
param gatewayName string = 'jslabs-appgw'
param adminUsername string
param sshPublicKey string
param jumpboxName string
param vmSize string = 'Standard_B1s'

module keyVaultModule 'security/keyvault.bicep' = {
  name: 'deployKeyVault'
  params: {
    location: location
    keyVaultName: keyVaultName
  }
}

module userIdentityModule 'security/userIdentity.bicep' = {
  name: 'deployUserIdentity'
  params: {
    location: location
    identityName: identityName
  }
}

module containerRegistryModule 'kubernetes/containerRegistry.bicep' = {
  name: 'deployContainerRegistry'
  params: {
    location: location
    registryName: registryName
    userIdentityPrincipalId: userIdentityModule.outputs.principalId
  }
}

module networkModule 'kubernetes/network.bicep' = {
  name: 'deployNetwork'
  params: {
    location: location
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
    subnetId: networkModule.outputs.subnetId
    userIdentityId: userIdentityModule.outputs.identityId
    gatewayName: gatewayName
  }
}

module bastionHostModule 'kubernetes/bastionHost.bicep' = {
  name: 'deployBastionHost'
  params: {
    adminUsername: adminUsername
    sshPublicKey: sshPublicKey
    computerName: jumpboxName
    vmSize: vmSize
  }
}

module roleAssignment 'security/roleAssignments.bicep' = {
  name: 'roleAssignment'
  params: {
    keyVaultId: keyVaultModule.outputs.keyVaultId
    userIdentityId: userIdentityModule.outputs.principalId
  }
}

