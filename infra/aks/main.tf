terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }

  backend "azurerm" {
    resource_group_name  = "example-tfstate"
    storage_account_name = "exampletfstatedev"
    container_name       = "tfstate"
    key                  = "aks/dev-aks.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "dev" {
  name     = "rg-dev-aks"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "dev" {
  name                = "dev-aks"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  dns_prefix          = "dev-aks"

  kubernetes_version = "1.32"
  sku_tier           = "Premium"
  support_plan       = "AKSLongTermSupport"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "None"

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    node_count           = 2
    orchestrator_version = "1.32"
    vnet_subnet_id       = var.node_subnet_id

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    environment = "dev"
    owner       = "platform-team"
  }
}
