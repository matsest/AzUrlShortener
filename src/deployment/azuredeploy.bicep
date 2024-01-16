@description('Name used as base-template to name the resources to be deployed in Azure.')
param baseName string = 'shortenertool'

@description('Optional (SKIP-THIS-RESOURCE): If provided, this is name of the Static Web App in this resource group. If not provided: API will be standalone')
param swaName string = 'SKIP-THIS-RESOURCE'

@description('Default URL used when key passed by the user is not found.')
param defaultRedirectUrl string = 'https://azure.com'

@description('The URL of GitHub (ending by .git)')
param gitHubURL string = 'https://github.com/microsoft/AzUrlShortener.git'

@description('Name of the branch to use when deploying (Default = main).')
param gitHubBranch string = 'main'

@description('Owner of this deployment, person to contact for question.')
param ownerName string = ''

@description('Location for the resources')
param location string = resourceGroup().location

var suffix = substring(toLower(uniqueString(resourceGroup().id, location)), 0, 5)
var funcAppName = toLower('${baseName}-${suffix}-fa')
var deployTinyBlazorAdmin = ((swaName == 'SKIP-THIS-RESOURCE') ? false : true)
var storageAccountName = toLower('${substring(baseName, 0, min(length(baseName), 16))}${suffix}sa')
var funcHostingPlanName = '${substring(baseName, 0, min(length(baseName), 13))}-${suffix}-asp'
var insightsAppName = '${substring(baseName, 0, min(length(baseName), 13))}-${suffix}-ai'

resource funcApp 'Microsoft.Web/sites@2023-01-01' = {
  name: funcAppName
  kind: 'functionapp'
  location: location
  tags: {
    Owner: ownerName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: insightsApp.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: insightsApp.properties.ConnectionString
        }
        {
          // TODO: Change to managed identity
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          // TODO: Change to managed identity
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${funcAppName}ba91'
        }
        {
          // TODO: Change to managed identity
          name: 'DataStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'defaultRedirectUrl'
          value: defaultRedirectUrl
        }
      ]
    }
    serverFarmId: funcHostingPlan.id
    use32BitWorkerProcess: true
    netFrameworkVersion: 'v6.0'
    clientAffinityEnabled: true
  }
}

resource funcAppName_web 'Microsoft.Web/sites/sourcecontrols@2023-01-01' = {
  parent: funcApp
  name: 'web'
  properties: {
    repoUrl: gitHubURL
    branch: gitHubBranch
    isManualIntegration: true
  }
}

resource funcAppName_authsettingsV2 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: funcApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      unauthenticatedClientAction: 'AllowAnonymous'
    }
  }
  dependsOn: [
    swa
    swaLinkedBackend
    swaUserProvidedFunctionApp
  ]
}

resource funcHostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: funcHostingPlanName
  location: location
  kind: ''
  tags: {
    Owner: ownerName
  }
  properties: {}
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
}

resource insightsApp 'Microsoft.Insights/components@2020-02-02' = {
  name: insightsAppName
  location: location
  tags: {
    Owner: ownerName
  }
  kind: ''
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: {
    displayName: storageAccountName
    Owner: ownerName
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
  }
}

resource swa 'Microsoft.Web/staticSites@2023-01-01' existing = if (deployTinyBlazorAdmin) {
  name: swaName
}

resource swaLinkedBackend 'Microsoft.Web/staticSites/linkedBackends@2023-01-01' = if (deployTinyBlazorAdmin) {
  parent: swa
  name: 'backend1'
  properties: {
    backendResourceId: funcApp.id
    region: location
  }
}

resource swaUserProvidedFunctionApp 'Microsoft.Web/staticSites/userProvidedFunctionApps@2023-01-01' = if (deployTinyBlazorAdmin) {
  parent: swa
  name: 'backend1'
  properties: {
    functionAppResourceId: funcApp.id
    functionAppRegion: location
  }
}

resource swaAppSettings 'Microsoft.Web/staticSites/config@2023-01-01' = if (deployTinyBlazorAdmin) {
  parent: swa
  name: 'appsettings'
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: insightsApp.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: insightsApp.properties.ConnectionString
  }
}
