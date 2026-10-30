// Rede virtual do ambiente (equivalente à VPC do projeto AWS)
param location string
param prefix string
param addressSpace string = '10.10.0.0/16'
param appsSubnetPrefix string = '10.10.0.0/23'

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet-${prefix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        // Sub-rede dedicada ao Container Apps Environment
        name: 'snet-apps'
        properties: {
          addressPrefix: appsSubnetPrefix
          delegations: [
            {
              name: 'containerapps'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

output appsSubnetId string = vnet.properties.subnets[0].id
