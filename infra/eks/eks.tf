############################################################
# kube-pilot EKS cluster — deployable and reachable.
#
# - Public API endpoint for kubectl / Argo CD
# - Graviton (ARM) + Spot nodes for cost optimization
# - EBS CSI driver add-on + IRSA for MySQL gp3 PVC
############################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Reachable from outside the VPC for hands-on practical.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  # This account's role lacks kms:TagResource and
  # logs:CreateLogGroup, so optional KMS secret encryption
  # key and CloudWatch control-plane logging are disabled.
  # Secrets still work with the existing EKS configuration.
  create_kms_key              = false
  cluster_encryption_config   = {}
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # Cluster admins are listed explicitly (var.cluster_admin_arns). The module's
  # "cluster creator" option is OFF on purpose: it grants admin only to whoever runs
  # `terraform apply` and removes the previous person's entry, which locked a team
  # member out of the cluster on 2026-11-18.
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    for name, arn in var.cluster_admin_arns : name => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  ##########################################################
  # NEW CODE START - HARNESS OIDC MONITORING ACCESS
  ##########################################################

  access_entries = {
    harness_monitoring = {
      principal_arn = "arn:aws:iam::105673693246:role/harness-oidc-admin-role"

      type = "STANDARD"

      kubernetes_groups = [
        "harness-eks-monitoring"
      ]

      policy_associations = {
        monitoring_view = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  ##########################################################
  # NEW CODE END - HARNESS OIDC MONITORING ACCESS
  ##########################################################

  ##########################################################
  # EXISTING EKS ADD-ONS
  ##########################################################

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}

    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  ##########################################################
  # EXISTING MANAGED NODE GROUPS
  ##########################################################

  eks_managed_node_groups = {

    # Graviton (ARM) + Spot for cost savings:
    #
    # - AL2023_ARM_64_STANDARD: Graviton AMI
    # - SPOT capacity for cost savings
    # - t4g.medium: 2 vCPU / 4 GiB example
    #
    # Keep ARM64-compatible images for workloads.

    general = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      capacity_type  = "SPOT"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }

    # Small On-Demand Graviton node reserved for
    # the Harness delegate.
    #
    # Taint prevents application pods from scheduling
    # unless they have a matching toleration.

    delegate = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      capacity_type  = "ON_DEMAND"
      instance_types = var.delegate_instance_types

      min_size     = 1
      max_size     = 1
      desired_size = 1

      labels = {
        workload = "harness-delegate"
      }

      taints = {
        delegate = {
          key    = "dedicated"
          value  = "harness-delegate"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  tags = var.tags
}

############################################################
# EXISTING CODE - EBS CSI DRIVER IRSA ROLE
############################################################

# IRSA role for the EBS CSI driver so it can
# create/attach EBS volumes.
#
# The original kube-pilot-ebs-csi role was orphaned.
# Retain the existing v3 role name.

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.cluster_name}-ebs-csi-v3"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn

      namespace_service_accounts = [
        "kube-system:ebs-csi-controller-sa"
      ]
    }
  }

  tags = var.tags
}

############################################################
# EXISTING CODE - DEFAULT GP3 STORAGE CLASS
############################################################

# Default gp3 StorageClass so PVCs like the
# application's MySQL volume bind automatically.

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"

  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks]
}

############################################################
# NEW CODE START - KUBERNETES MONITORING CLUSTER ROLE
############################################################

# Provides read-only access to:
# - Kubernetes nodes and node status
# - Pods and pod status
# - Namespaces
# - Events
# - Node CPU and memory metrics
# - Pod CPU and memory metrics

resource "kubernetes_cluster_role_v1" "harness_monitoring" {
  metadata {
    name = "harness-eks-monitoring-readonly"
  }

  ##########################################################
  # READ NODES, PODS, NAMESPACES, EVENTS
  ##########################################################

  rule {
    api_groups = [""]

    resources = [
      "nodes",
      "nodes/status",
      "pods",
      "pods/status",
      "namespaces",
      "events"
    ]

    verbs = [
      "get",
      "list",
      "watch"
    ]
  }

  ##########################################################
  # READ NODE AND POD CPU/MEMORY METRICS
  ##########################################################

  rule {
    api_groups = [
      "metrics.k8s.io"
    ]

    resources = [
      "nodes",
      "pods"
    ]

    verbs = [
      "get",
      "list"
    ]
  }

  depends_on = [module.eks]
}

############################################################
# NEW CODE END - KUBERNETES MONITORING CLUSTER ROLE
############################################################

############################################################
# NEW CODE START - HARNESS MONITORING ROLE BINDING
############################################################

# Connect the Kubernetes group assigned to the
# Harness IAM access entry with the monitoring ClusterRole.

resource "kubernetes_cluster_role_binding_v1" "harness_monitoring" {
  metadata {
    name = "harness-eks-monitoring-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"

    name = kubernetes_cluster_role_v1.harness_monitoring.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "harness-eks-monitoring"
    api_group = "rbac.authorization.k8s.io"
  }
}

############################################################
# NEW CODE END - HARNESS MONITORING ROLE BINDING
############################################################
