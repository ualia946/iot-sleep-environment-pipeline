resource "azurerm_storage_account" "st_account" {
  resource_group_name = data.azurerm_resource_group.rg.name

  name = "stiotsleepivelin"
  
  # CAMBIO AQUÍ: Añadimos data.
  location = data.azurerm_resource_group.rg.location

  access_tier = "Hot"
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "st_share" {
  name = "aca-files"
  storage_account_id = azurerm_storage_account.st_account.id
  quota = 1
}

# Acceso del entorno de contenedores al volumen compartido.
resource "azurerm_container_app_environment_storage" "cae_storage" {
  name = "aca-storage"
  container_app_environment_id = data.azurerm_container_app_environment.cae.id
  
  account_name = azurerm_storage_account.st_account.name
  share_name = azurerm_storage_share.st_share.name
  access_key = azurerm_storage_account.st_account.primary_access_key
  access_mode = "ReadWrite"
}

# Contenido de InfluxDB
resource "azurerm_storage_share_directory" "dir_influxdb" {
  name                 = "influxdb"
  storage_share_url = azurerm_storage_share.st_share.url
}

# Contenido de Mosquitto
resource "azurerm_storage_share_directory" "dir_mosquitto" {
  name                 = "mosquitto"
  storage_share_url = azurerm_storage_share.st_share.url
}

resource "azurerm_storage_share_directory" "dir_mosquitto_certs" {
  name                 = "${azurerm_storage_share_directory.dir_mosquitto.name}/certs"
  storage_share_url = azurerm_storage_share.st_share.url
  depends_on       = [azurerm_storage_share_directory.dir_mosquitto]
}

resource "azurerm_storage_share_file" "mosquitto_conf" {
  name = "mosquitto.conf"
  storage_share_url = azurerm_storage_share.st_share.url

  path = azurerm_storage_share_directory.dir_mosquitto.name
  source = "../../data-processing/mosquitto/mosquitto.conf"
}

resource "azurerm_storage_share_file" "certificados" {
  for_each = fileset("../../data-processing/mosquitto/certs/", "*")

  name = each.value
  storage_share_url = azurerm_storage_share.st_share.url
  path = azurerm_storage_share_directory.dir_mosquitto_certs.name

  source = "../../data-processing/mosquitto/certs/${each.value}"
}

# Contenido de Telegraf
resource "azurerm_storage_share_directory" "dir_telegraf" {
  name                 = "telegraf"
  storage_share_url = azurerm_storage_share.st_share.url
}

# Contenido de ETL_Python
resource "azurerm_storage_share_directory" "dir_etl_python" {
  name                 = "etl_python"
  storage_share_url = azurerm_storage_share.st_share.url
}