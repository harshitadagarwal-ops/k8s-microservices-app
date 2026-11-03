region          = "us-east-1"
cluster_name    = "kube-pilot"
cluster_version = "1.34"
vpc_cidr        = "10.0.0.0/16"

# Graviton (ARM) + Spot node group. >=2 vCPU types only (delegate needs 1 CPU).
node_instance_types = [
  "t4g.large", "t4g.xlarge",
  "m6g.large", "m7g.large",
  "c6g.large", "c7g.large",
  "r6g.large",
]
node_min_size     = 2
node_max_size     = 3
node_desired_size = 2

# AWS Load Balancer Controller (ALB/NLB for Ingress). Set false to skip.
enable_lb_controller        = true
lb_controller_chart_version = "1.8.1"
