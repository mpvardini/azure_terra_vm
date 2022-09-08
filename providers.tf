terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "239d18e5-9b18-45af-b093-7df9179936f6"
  client_id       = "c884755a-feb4-4960-8e8e-a61c969d918d"
  client_secret   = var.client_secretkey
  tenant_id       = "f3ab8a7d-7bae-48cb-a130-9deabd44c2ca"
}