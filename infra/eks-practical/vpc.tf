# VPC for the EKS cluster.
# The repo's original infra/eks assumes a pre-existing VPC; this practical
# root creates its own so it is fully self-contained and deployable.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first two AZs in the region. EKS needs subnets in >= 2 AZs.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  # One NAT gateway (shared) keeps cost down for a practical.
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Subnet tags required by EKS so it can discover subnets for load balancers.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
  }

  tags = var.tags
}
