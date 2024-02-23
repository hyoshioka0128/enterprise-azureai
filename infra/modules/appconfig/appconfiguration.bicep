param name string 
param location string
param azureMonitorDataCollectionEndPointUrl string
param azureMonitorDataCollectionRuleImmutableId string
param azureMonitorDataCollectionRuleStream string
param proxyManagedIdentityName string
param chatappIdentityName string
param proxyConfig object
param cosmosDbEndPoint string
param vNetName string
param privateEndpointSubnetName string
param appconfigPrivateEndpointName string
param appconfigPrivateDnsZoneName string
param apimEndpoint string
param deployChatApp bool
param keyVaultUrl string
param openAIApiVersion string


resource proxyIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: proxyManagedIdentityName
}

resource chatappIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chatappIdentityName
}

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  properties:  {
    publicNetworkAccess: 'Enabled'
  }
}

module proxyRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'proxy-roleAssignment'
  params: {
    principalId: proxyIdentity.properties.principalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'proxy-roleassignment-AppConfigurationDataReader'
  }
}

module chatappRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'chatapp-roleAssignment'
  params: {
    principalId: chatappIdentity.properties.principalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'chatapp-roleassignment-AppConfigurationDataReader'
  }
}


resource dataCollectionEndpoint 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionEndPoint'
  parent: appconfig
  properties:{
    value: azureMonitorDataCollectionEndPointUrl
  }
}

resource dataCollectionRuleImmutableId 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionRuleImmutableId'
  parent: appconfig
  properties:{
    value: azureMonitorDataCollectionRuleImmutableId
  }
}

resource dataCollectionRuleStream 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionRuleStream'
  parent: appconfig
  properties:{
    value: azureMonitorDataCollectionRuleStream
  }
}

resource EntraIdTenantId 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'EntraId:TenantId'
  parent: appconfig
  properties:{
    value: subscription().tenantId
  }
}

resource proxyConfiguration 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureAIProxy:ProxyConfig'
  parent: appconfig
  properties:{
    value: replace(string(proxyConfig),',{}', '')
  }
}

resource cosmosDb 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if(deployChatApp) {
  name: 'AzureChat:CosmosDbEndPoint'
  parent: appconfig
  properties:{
    value: cosmosDbEndPoint
  }
}

//this will be used to create the departments in the app config store for the chat app
var departmentsConfig = [
  {
    name: 'Finance'
  }
  {
    name: 'Marketing'
  }
]

resource departments 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' =  if(deployChatApp){
  name: 'AzureChat:Departments'
  parent: appconfig
  properties:{
    value: string(departmentsConfig)
  }
}

//this will be used to create the deployments in the app config store for the chat app
var deploymentsConfig = [
  {
    type: 'chat'
    deployment: 'gpt-35-turbo'
  }
  {
    type: 'embeddings'
    deployment: 'text-embeddings-ada-002'
  }
]

resource deployments 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if(deployChatApp) {
  name: 'AzureChat:Deployments'
  parent: appconfig
  properties:{
    value: string(deploymentsConfig)
  }
}

resource OpenAIEndpoint 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if(deployChatApp) {
  name: 'AzureChat:ApimEndpoint'
  parent: appconfig
  properties:{
    value: apimEndpoint
  }
}

resource KeyVaultEndpoint 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if(deployChatApp) {
  name: 'AzureChat:Keyvault'
  parent: appconfig
  properties:{
    value: keyVaultUrl
  }
}

resource OpenAIAPIVersion 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = if(deployChatApp) {
  name: 'AzureChat:OpenAIApiVersion'
  parent: appconfig
  properties:{
    value: openAIApiVersion
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  //set config keys first
  dependsOn: [
    departments 
    deployments 
    proxyConfiguration
    cosmosDb
    EntraIdTenantId
    dataCollectionRuleStream 
    dataCollectionRuleImmutableId
    dataCollectionEndpoint
  ]
  name: '${appconfig.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'configurationStores'
    ]
    dnsZoneName: appconfigPrivateDnsZoneName
    name: appconfigPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: appconfig.id
    vNetName: vNetName
    location: location
  }
}

output appConfigEndPoint string = appconfig.properties.endpoint

