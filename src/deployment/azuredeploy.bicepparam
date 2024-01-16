using './azuredeploy.bicep'

param baseName = 'shortenertool'
param swaName = 'shortenertool-swa'
param defaultRedirectUrl = 'https://azure.com'
param gitHubURL = 'https://github.com/matsest/AzUrlShortener.git'
param gitHubBranch = 'dev'
param ownerName = 'matsest'
param location = 'westeurope'
