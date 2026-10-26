region            = "eu-west-1"
cluster_name      = "kube-pilots"
cluster_version   = "1.32"
vpc_cidr          = "10.0.0.0/16"

node_instance_types = ["t3.medium"]
node_min_size       = 2
node_max_size       = 3
node_desired_size   = 2
