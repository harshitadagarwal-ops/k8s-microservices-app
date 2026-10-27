output "cluster_name" {
  value = google_container_cluster.staging.name
}

output "cluster_endpoint" {
  value = google_container_cluster.staging.endpoint
}
