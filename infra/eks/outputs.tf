output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name."
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API server endpoint."
}

output "cluster_version" {
  value       = module.eks.cluster_version
  description = "Kubernetes version of the control plane."
}

output "region" {
  value       = var.region
  description = "Region the cluster runs in."
}

output "update_kubeconfig_command" {
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
  description = "Run this to point kubectl at the new cluster."
}
