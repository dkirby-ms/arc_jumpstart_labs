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
@secure()
param adminPassword string
param vmSize string = 'Standard_D2s_v5'
param deployBastion bool = false

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
    userIdentityPrincipalId: userIdentityModule.outputs.objectId
  }
}

module networkModule 'kubernetes/network.bicep' = {
  name: 'deployNetwork'
  params: {
    location: location
    subnetNameCloud: 'subnet-cloud'
    subnetNameCloudK3s: 'subnet-k3s'
    virtualNetworkNameCloud: 'aksVnet'
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
    subnetId: networkModule.outputs.k3sSubnetId
    uamiClientId: userIdentityModule.outputs.clientId
    uamiObjectId: userIdentityModule.outputs.objectId
    userIdentityId: userIdentityModule.outputs.identityId
    gatewayName: gatewayName
  }
  dependsOn: [
    roleAssignment
  ]
}

module roleAssignment 'security/roleAssignments.bicep' = {
  name: 'roleAssignment'
  params: {
    keyVaultId: keyVaultModule.outputs.keyVaultId
    userIdentityId: userIdentityModule.outputs.objectId
  }
}

module clientVmModule 'clientVm/clientVm.bicep' = {
  name: 'deployClientVm'
  params: {
    windowsAdminUsername: adminUsername
    windowsAdminPassword: adminPassword
    vmSize: vmSize
    deployBastion: deployBastion
    subnetId: networkModule.outputs.cloudSubnetId
  }
}

