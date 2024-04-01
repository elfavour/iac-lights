output "cluster_name" {
  description = "Azure Kubernetes Service Cluster Name"
  value       = module.aks_cluster.name
}

output "cluster_endpoint" {
  description = "Endpoint for AKS "
  value       = module.aks.cluster_endpoint
}

output "kubeconfig_path" {
  value = abspath("${path.root}/kubeconfig")
}

output "cluster_name" {
  value = local.cluster_name
}