variable "unique" {
  type = "string"
}
variable "project_name" {
  type = "string"
}
variable "resource_group" {
  type = "string"
}
variable "location" {
  type = "string"
}
variable "subscription_id" {
  type = "string"
}
variable "tenant_id" {
  type = "string"
}
variable "client_id" {
  type = "string"
}
variable "client_secret" {
  type = "string"
}
variable "cluster_ssh_key_value" {
  type = "string"
}
variable "cluster_service_principal_id" {
  type = "string"
}
variable "cluster_service_principal_key" {
  type = "string"
}
variable "cluster_service_principal_oid" {
  type = "string"
}
variable "agent_count" {
  default = 3
}

locals {
  cluster_name    = "clusteraks${var.unique}"
  cluster_dns_prefix    = "cluster-dns-${var.unique}"
  cluster_fqdn    = "cluster-fqdn-${var.unique}"
  registry_name    = "registryacr${var.unique}" 
}

# Configure the Azure Provider
provider "azurerm" {
  version                   = "~>1.5"
  client_id                 = "${var.client_id}"
  client_secret             = "${var.client_secret}"
  tenant_id                 = "${var.tenant_id}"
  subscription_id           = "${var.subscription_id}"
}

# terraform {
#     backend "azurerm" {}
# }

# data islands to use
data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# create a resource group
resource "azurerm_resource_group" "main" {
  name                      = "${var.resource_group}"
  location                  = "${var.location}"
}
# create storage account
resource "azurerm_storage_account" "storage" {
  name                        = "storagesa${var.unique}"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  location                    = "${var.location}"
  account_tier                = "Standard"
  account_replication_type    = "LRS"
}

# create a virtual network
resource "azurerm_virtual_network" "network" {
  name                        = "network-vnet-${var.unique}"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  location                    = "${var.location}"
  address_space               = ["10.0.0.0/16"]
}
# create host subnet
resource "azurerm_subnet" "cluster" {
  name                        = "cluster-sn-${var.unique}"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  virtual_network_name        = "${azurerm_virtual_network.network.name}"
  address_prefix              = "10.0.1.0/24"
}
# create registry
resource "azurerm_container_registry" "acr" {
  name                     = "${local.registry_name}"
  resource_group_name      = "${azurerm_resource_group.main.name}"
  location                 = "${var.location}"
  sku                      = "Standard"
  admin_enabled            = true
}

# create log analytis workspace
resource "azurerm_log_analytics_workspace" "analytics" {
  name                        = "analytics-log-${var.unique}"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  location                    = "${var.location}"
  sku                         = "Free"
}

resource "azurerm_log_analytics_solution" "test" {
    solution_name         = "ContainerInsights"
    location              = "${azurerm_log_analytics_workspace.analytics.location}"
    resource_group_name   = "${azurerm_resource_group.main.name}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.analytics.id}"
    workspace_name        = "${azurerm_log_analytics_workspace.analytics.name}"
    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "cluster" {
    name                = "${local.cluster_name}"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.main.name}"
    dns_prefix          = "${local.cluster_dns_prefix}"

    linux_profile {
        admin_username = "styx"

        ssh_key {
            key_data = "${var.cluster_ssh_key_value}"
        }
    }

    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.agent_count}"
        vm_size         = "Standard_DS1_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30
    }

    service_principal {
        client_id     = "${var.cluster_service_principal_id}"
        client_secret = "${var.cluster_service_principal_key}"
    }

    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.analytics.id}"
        }
    }
}

output "registry_name" {
  value = "${local.registry_name}"
}
output "registry_user_name" {
  value = "${azurerm_container_registry.acr.admin_username}"
}
output "registry_password" {
  value = "${azurerm_container_registry.acr.admin_password}"
}
output "cluster_name" {
  value = "${local.cluster_name}"
}


output "vnet_id" {
  value = "${azurerm_virtual_network.network.id}"
}

output "cluster_subnet_id" {
  value = "${azurerm_subnet.cluster.id}"
}
