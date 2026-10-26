# EKS 1.32 cluster — a deployable, reachable version of the repo's infra/eks.
#
# Differences from infra/eks (the Preflight fixture) are intentional:
#   - public API endpoint        -> so kubectl / Argo CD work from your laptop
#   - AL2023 node AMI            -> current default, valid on 1.32..1.36
#                                   (the fixture uses AL2, planted finding F10)
#   - EBS CSI driver add-on + IRSA -> so the app's MySQL gp3 PVC can bind
#   - smaller/cheaper nodes      -> 2x t3.medium for a practical

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Reachable from outside the VPC for a hands-on practical.
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  # Let the creating IAM principal administer the cluster (so your `harshita`
  # user can run kubectl immediately after apply).
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }

  tags = var.tags
}

# IRSA role for the EBS CSI driver so it can create/attach EBS volumes.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# Default gp3 StorageClass so PVCs like the app's MySQL volume bind automatically.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks]
}
