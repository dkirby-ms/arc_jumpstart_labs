param location string
param clusterName string
param nodeCount int
param minCount int
param maxCount int
param nodeSize string
param userIdentityId string
param subnetId string
param gatewayName string


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
    dnsPrefix: clusterName
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: nodeCount
        vmSize: nodeSize
        maxCount: maxCount
        minCount: minCount
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'userDefinedRouting'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
    }
    addonProfiles: {
      ingressApplicationGateway: {
        enabled: true
        config: {
          gatewayId: resourceId('Microsoft.Network/applicationGateways', gatewayName)
          subnetId: subnetId
        }
      }
    }
    identityProfile: {
      kubeletidentity: {
        resourceId: userIdentityId
      }
    }
    enableRBAC: true
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
  }
}

output aksClusterId string = aksCluster.id
output aksClusterName string = aksCluster.name
