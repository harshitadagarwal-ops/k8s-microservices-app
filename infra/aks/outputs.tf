output "cluster_name" {
  value = azurerm_kubernetes_cluster.dev.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.dev.id
}
