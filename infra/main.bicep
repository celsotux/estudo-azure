// Infraestrutura base: registro de imagens e Container Apps Environment
targetScope = 'resourceGroup'

@description('Prefixo usado no nome dos recursos')
param prefix string = 'estudo'

param location string = resourceGroup().location

module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    prefix: prefix
  }
}

module environment 'modules/environment.bicep' = {
  name: 'environment'
  params: {
    location: location
    prefix: prefix
  }
}

output acrName string = registry.outputs.acrName
output acrLoginServer string = registry.outputs.acrLoginServer
output identityId string = registry.outputs.identityId
output environmentId string = environment.outputs.environmentId
