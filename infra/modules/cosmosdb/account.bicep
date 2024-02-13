param name string 
param location string
param vNetName string
param privateEndpointSubnetName string
param cosmosPrivateEndpointName string
param cosmosAccountPrivateDnsZoneName string
param chatAppIdentityName string


var defaultConsistencyLevel = 'Session'


resource chatAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing ={
  name: chatAppIdentityName
}


resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    databaseAccountOfferType:'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

var CosmosDBBuiltInDataContributor = {
  id: '/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
}
resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid('${account.name},${CosmosDBBuiltInDataContributor.id}, chatAppIdentity.properties.principalId')  
  parent: account
  properties: {
    principalId: chatAppIdentity.properties.principalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
  
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'Sql'
    ]
    dnsZoneName: cosmosAccountPrivateDnsZoneName
    name: cosmosPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: account.id
    vNetName: vNetName
    location: location
  }
}


output cosmosDbEndPoint string = account.properties.documentEndpoint
