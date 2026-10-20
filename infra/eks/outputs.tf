output "cluster_endpoint" {
  value = aws_eks_cluster.prod.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.prod.name
}

output "cluster_version" {
  value = aws_eks_cluster.prod.version
}
