param location string = resourceGroup().location
param clusterName string = 'myAksCluster'
param nodeCount int = 1
param minCount int = 1
param maxCount int = 3
param nodeSize string = 'Standard_B2s' // Updated to a more cost-effective node size
param userIdentityId string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-07-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentityId}': {}
    }
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: nodeSize
        minCount: minCount
        maxCount: maxCount
        enableAutoScaling: true
        mode: 'System'
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    dnsPrefix: clusterName
    servicePrincipalProfile: {
      clientId: 'msi'
    }
  }
}

output aksClusterPrincipalId string = aksCluster.identity.userAssignedIdentities[userIdentityId].principalId
