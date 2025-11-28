@description('Admin password for the Sophos Firewall')
@minLength(12)
@secure()
param adminPassword string

@description('Location for all resources')
param location string = 'switzerlandnorth'

@description('Admin username for the Sophos Firewall')
param adminUsername string = 'raptusadmin'

@description('VM size for the Sophos Firewall')
param vmSize string = 'Standard_B2als_v2'

@description('Sophos Firewall image version')
param sophosImageVersion string = 'latest'

var vmName = 'cvsgate'
var vnetName = 'vnet-site-cloud'
var subnetWanName = 'snet-wan-public'
var subnetLanName = 'snet-lan-protected'
var nicWanName = '${vmName}-nic-wan'
var nicLanName = '${vmName}-nic-lan'
var publicIPName = '${vmName}-pip'
var nsgWanName = 'nsg-wan-public'
var nsgLanName = 'nsg-lan-protected'
var vnetAddressPrefix = '172.20.0.0/16'
var subnetWanPrefix = '172.20.200.0/24'
var subnetLanPrefix = '172.20.10.0/24'
var wanPrivateIP = '172.20.200.4'
var lanPrivateIP = '172.20.10.4'

// Network Security Group for WAN subnet
resource nsgWan 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgWanName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowGateInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '172.20.200.4'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowGateOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '172.20.200.4'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Outbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

// Network Security Group for LAN subnet
resource nsgLan 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgLanName
  location: location
  properties: {
    securityRules: []
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetWanName
        properties: {
          addressPrefix: subnetWanPrefix
          networkSecurityGroup: {
            id: nsgWan.id
          }
        }
      }
      {
        name: subnetLanName
        properties: {
          addressPrefix: subnetLanPrefix
          networkSecurityGroup: {
            id: nsgLan.id
          }
        }
      }
    ]
  }
}

// Public IP for WAN interface
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower(vmName)
    }
  }
}

// WAN Network Interface
resource nicWan 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicWanName
  location: location
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig-wan'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: wanPrivateIP
          publicIPAddress: {
            id: publicIP.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// LAN Network Interface
resource nicLan 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicLanName
  location: location
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig-lan'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: lanPrivateIP
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

// Sophos XG Firewall Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  plan: {
    name: 'byol'
    publisher: 'sophos'
    product: 'sophos-xg'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'sophos'
        offer: 'sophos-xg'
        sku: 'byol'
        version: sophosImageVersion
      }
      osDisk: {
        name: '${vmName}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicWan.id
          properties: {
            primary: true
          }
        }
        {
          id: nicLan.id
          properties: {
            primary: false
          }
        }
      ]
    }
  }
}

// Outputs
output publicIP string = publicIP.properties.ipAddress
output fqdn string = publicIP.properties.dnsSettings.fqdn
output vmName string = vm.name
output wanPrivateIP string = nicWan.properties.ipConfigurations[0].properties.privateIPAddress
output lanPrivateIP string = nicLan.properties.ipConfigurations[0].properties.privateIPAddress
