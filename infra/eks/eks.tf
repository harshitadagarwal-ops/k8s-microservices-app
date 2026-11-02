# kube-pilot EKS cluster — deployable and reachable.
#   - public API endpoint        -> so kubectl / Argo CD work from your laptop
#   - Graviton (ARM) + Spot nodes -> cost-optimized (see node group below)
#   - EBS CSI driver add-on + IRSA -> so the app's MySQL gp3 PVC can bind

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

  # This account's role lacks kms:TagResource and logs:CreateLogGroup, so the
  # module's optional KMS secret-encryption key and CloudWatch control-plane
  # logging are disabled. Secrets still work (stored unencrypted-at-rest by the
  # default AWS-managed mechanism); control-plane logs just aren't shipped.
  create_kms_key                         = false
  cluster_encryption_config              = {}
  create_cloudwatch_log_group            = false
  cluster_enabled_log_types              = []

  # Let the creating IAM principal administer the cluster.
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
    # Graviton (ARM) + Spot for cost savings:
    #   - AL2023_ARM_64_STANDARD  -> Graviton AMI (~20% cheaper than x86)
    #   - capacity_type SPOT       -> up to ~70% off on-demand
    #   - t4g.medium               -> Graviton equiv of t3.medium (2 vCPU / 4 GiB)
    #     kept at medium (not smaller) because node memory requests ~83% and the
    #     Harness delegate alone requests ~2Gi; smaller would break scheduling.
    # NOTE: all container images must have arm64 builds (app images rebuilt
    # multi-arch; delegate image is already multi-arch).
    general = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      capacity_type  = "SPOT"
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
