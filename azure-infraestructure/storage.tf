resource "azurerm_storage_account" "st_account" {
  resource_group_name = azurerm_resource_group.rg.name

  name = "stiotsleepivelin"
  location = azurerm_resource_group.rg.location

  access_tier = "Hot"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "st_share" {
  name = "aca-files"
  storage_account_id = azurerm_storage_account.st_account.id
  quota = 1
  
}

resource "azurerm_storage_share_directory" "dir_influxdb" {
  name                 = "influxdb"
  storage_share_url = azurerm_storage_share.st_share.url
}

resource "azurerm_storage_share_directory" "dir_mosquitto" {
  name                 = "mosquitto"
  storage_share_url = azurerm_storage_share.st_share.url
}

resource "azurerm_storage_share_directory" "dir_telegraf" {
  name                 = "telegraf"
  storage_share_url = azurerm_storage_share.st_share.url
}

resource "azurerm_storage_share_directory" "dir_etl_python" {
  name                 = "etl_python"
  storage_share_url = azurerm_storage_share.st_share.url
}