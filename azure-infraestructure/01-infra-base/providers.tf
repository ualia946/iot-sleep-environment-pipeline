terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = ">= 3.100.0"
    }
  }
  backend "azurerm" {
    resource_group_name = "rg-terraform-state"
    storage_account_name = "stiotsleepive"
    container_name = "tfstate"
    key = "iot-sleep-base.terraform.tfstate"
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    
  }
}

resource "azurerm_resource_group" "rg" {
  name = "rg-iot-sleep"
  location = "spaincentral"
}