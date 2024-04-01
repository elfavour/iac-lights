locals {
  cluster_name = var.clusterName
}

resource "azurerm_resource_group" "default" {
  name     = var.clusterName
  location = var.region
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = var.clusterName
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = var.clusterName

  default_node_pool {
    name       = "test"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
}

provider "azurerm" {
  features {}
}

module "aks-cluster" {
  source       = "./aks-cluster"
  cluster_name = local.clusterName
  location     = var.region
}

module "kubernetes-config" {
  depends_on   = [module.aks_cluster]
  source       = "./kubernetes-config"
  cluster_name = local.clusterName
  kubeconfig   = data.azurerm_kubernetes_cluster.default.kube_config_raw
}

# Monitoring setup
resource "azurerm_monitor_diagnostic_setting" "aks_diagnostic" {
  name                       = "aks"
  target_resource_id         = azurerm_kubernetes_cluster.aks_cluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id

  log {
    category = "kube-apiserver"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}
