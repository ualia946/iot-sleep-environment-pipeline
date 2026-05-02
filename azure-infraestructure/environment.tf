resource "azurerm_log_analytics_workspace" "law" {
  resource_group_name = azurerm_resource_group.rg.name

  name = "law-iot-sleep"
  location = azurerm_resource_group.rg.location

  sku = "PerGB2018"
  retention_in_days = 30
}

resource "azurerm_container_app_environment" "cae" {
  resource_group_name = azurerm_resource_group.rg.name

  name = "cae-iot-sleep"
  location = azurerm_resource_group.rg.location

  logs_destination           = "log-analytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  infrastructure_subnet_id = azurerm_subnet.snet_aca.id
}

resource "azurerm_network_security_group" "nsg_cae" {
  name = "nsg-cae"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_8883" {
  name                        = "Allow_8883"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8883"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_cae.name
}

resource "azurerm_virtual_network" "vnet" {
  name = "vnet"
  address_space = [ "10.0.0.0/16" ]
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_aca" {
  name                 = "snet-aca-env"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  

  address_prefixes     = ["10.0.4.0/23"] 

  delegation {
    name = "aca-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_to_snet" {
  subnet_id                 = azurerm_subnet.snet_aca.id
  network_security_group_id = azurerm_network_security_group.nsg_cae.id
}


