data "azurerm_key_vault_secret" "ssh_key" {
  name         = "test-ssh-key"
  key_vault_id = "/subscriptions/{subscription-id}/resourceGroups/prod-skaf-tfstate-rg/providers/Microsoft.KeyVault/vaults/test-ssh-key-skaf"
}

# There are two types of managed idetities "System assigned" & "UserAssigned". User-assigned managed identities can be used on multiple resources.
resource "azurerm_user_assigned_identity" "identity" {
  name                = "aksidentity"
  resource_group_name = "AKS-resource-group"
  location            = "eastus"
}

module "aks_cluster" {
  depends_on = [module.vnet, azurerm_user_assigned_identity.identity,]
  source     = "squareops/aks/azurerm"
  name                               = "aks-cluster"
  environment                        = "prod"
  kubernetes_version                 = "1.26.3"
  create_resource_group              = false  # Enable if you want to a create resource group for AKS cluster.
  existing_resource_group_name       = "AKS-resource-group"
  resource_group_location            = "eastus"
  user_assigned_identity_id          = azurerm_user_assigned_identity.identity.id
  principal_id                       = azurerm_user_assigned_identity.identity.principal_id
  network_plugin                     = "azure"
  net_profile_dns_service_ip         = "192.168.0.10" # IP address within the Kubernetes service address range that will be used by cluster service discovery. Don't use the first IP address in your address range. The first address in your subnet range is used for the kubernetes.default.svc.cluster.local address.
  net_profile_pod_cidr               = "10.244.0.0/16" # For aks pods cidr, when choosen "azure" network plugin these value will be passed as null.
  net_profile_docker_bridge_cidr     = "172.17.0.1/16" # It's required to select a CIDR for the Docker bridge network address because otherwise Docker will pick a subnet automatically, which could conflict with other CIDRs. You must pick an address space that doesn't collide with the rest of the CIDRs on your networks, including the cluster's service CIDR and pod CIDR. Default of 172.17.0.1/16.
  net_profile_service_cidr           = "192.168.0.0/16" # This range shouldn't be used by any network element on or connected to this virtual network. Service address CIDR must be smaller than /12. You can reuse this range across different AKS clusters.
  default_agent_pool_name            = "infra"
  default_agent_pool_count           = "1"
  default_agent_pool_size            = "Standard_DS2_v2"
  host_encryption_enabled            = false
  default_node_labels                = { Addon-Services = "true" }
  os_disk_size_gb                    = 30
  auto_scaling_enabled               = true
  agents_min_count                   = 1
  agents_max_count                   = 2
  node_public_ip_enabled             = false  
  agents_availability_zones          = ["1", "2", "3"] 
  rbac_enabled                       = true
  oidc_issuer_enabled                = true
  open_service_mesh_enabled          = false  
  private_cluster_enabled            = false  # AKS Cluster endpoint access, Disable for public access
  sku_tier                           = "Free"
  subnet_id                          = ["10.0.0.0/24", "10.0.0.1/24"]
  admin_username                     = "azureuser"  # node pool username
  public_ssh_key                     = data.azurerm_key_vault_secret.ssh_key.value
  agents_type                        = "VirtualMachineScaleSets"  
  net_profile_outbound_type          = "loadBalancer"   
  log_analytics_workspace_sku        = "PerGB2018" 
  log_analytics_solution_enabled     = true 
  control_plane_logs_scrape_enabled  = true 
  control_plane_monitor_name         = format("%s-%s-aks-control-plane-logs-monitor", local.name, local.environment) # Control plane logs monitoring such as "kube-apiserver", "cloud-controller-manager", "kube-scheduler"
  additional_tags                    = local.additional_tags
}

module "aks_managed_node_pool" {
  depends_on = [module.aks_cluster]
  source     = "squareops/aks/azurerm//modules/managed_node_pools"

  resource_group_name   = "AKS-resource-group"
  orchestrator_version  = "1.26.3"
  location              = "eastus"
  vnet_subnet_id        = ["10.0.0.0/24", "10.0.0.1/24"]
  kubernetes_cluster_id = module.aks_cluster.kubernetes_cluster_id
  node_pools = {
    app = {
      vm_size                  = "Standard_DS2_v2"
      auto_scaling_enabled     = true
      os_disk_size_gb          = 20
      os_disk_type             = "Managed"
      node_count               = 1
      min_count                = 1
      max_count                = 2
      availability_zones       = ["1", "2", "3"]
      enable_node_public_ip    = false # if set to true node_public_ip_prefix_id is required
      node_public_ip_prefix_id = ""
      node_labels              = { App-service = "true" }
      node_taints              = ["workload=example:NoSchedule"]
      host_encryption_enabled  = false
      max_pods                 = 30
      agents_tags              = local.additional_tags
    },
 }
}