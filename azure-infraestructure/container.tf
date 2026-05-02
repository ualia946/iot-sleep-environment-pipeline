resource "azurerm_container_app" "mosquitto" {
  name                         = "aca-mosquitto"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8883
    exposed_port               = 8883
    transport                  = "tcp"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    container {
      name   = "mosquitto"
      image  = "docker.io/eclipse-mosquitto:2.0"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "vol-aca-files"
        path     = "/mosquitto/config"
        sub_path = azurerm_storage_share_directory.dir_mosquitto.name
      }
    }

    volume {
      name         = "vol-aca-files"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.cae_storage.name
    }
  }
}