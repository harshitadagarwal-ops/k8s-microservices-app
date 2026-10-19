terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "s3" {
    bucket = "example-tfstate-prod"
    key    = "eks/prod-eks.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.region
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.6"

  cluster_name    = "prod-eks"
  cluster_version = "1.32"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access = false
  enable_irsa                    = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.11.4-eksbuild.2"
    }
    kube-proxy = {
      addon_version = "v1.32.0-eksbuild.2"
    }
    vpc-cni = {
      addon_version = "v1.19.2-eksbuild.1"
    }
  }

  eks_managed_node_groups = {
    general = {
      ami_type       = "AL2_x86_64"
      instance_types = ["m5.large"]

      min_size     = 3
      max_size     = 6
      desired_size = 3

      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        yum install -y amazon-ssm-agent
        systemctl enable --now amazon-ssm-agent
      EOT
    }
  }

  tags = {
    environment = "prod"
    owner       = "platform-team"
  }
}
