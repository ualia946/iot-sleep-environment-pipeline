data "azurerm_resource_group" "rg" {
  name = "rg-iot-sleep"
}

data "azurerm_container_app_environment" "cae" {
  name                = "cae-iot-sleep"
  resource_group_name = data.azurerm_resource_group.rg.name
}