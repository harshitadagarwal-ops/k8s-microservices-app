region          = "us-east-1"
cluster_name    = "kube-pilot"
cluster_version = "1.32"
vpc_cidr        = "10.0.0.0/16"

node_instance_types = ["t3.medium"]
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 1

# AWS Load Balancer Controller (ALB/NLB for Ingress). Set false to skip.
enable_lb_controller        = true
lb_controller_chart_version = "1.8.1"
