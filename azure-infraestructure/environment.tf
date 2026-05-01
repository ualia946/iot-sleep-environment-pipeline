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
}