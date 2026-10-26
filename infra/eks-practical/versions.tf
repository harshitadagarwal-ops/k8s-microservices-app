terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }

  # State lives in the S3 bucket + DynamoDB lock table created by the
  # bootstrap root (infra/eks-practical/bootstrap/). Those must exist first.
  backend "s3" {
    bucket         = "kube-pilots-tfstate-058264184834-euw1"
    key            = "kube-pilots/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "kube-pilots-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# Kubernetes provider is pointed at the cluster this root creates.
# Auth uses a short-lived token from `aws eks get-token` via exec.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
  }
}
