# Bootstrap root: creates the S3 bucket + DynamoDB table that hold the
# Terraform state for the main EKS root.
#
# This root uses LOCAL state on purpose: it is the "chicken and egg" layer
# that must exist before an S3 backend can be used anywhere else.
# Run this ONCE, then the main root points its backend "s3" at these resources.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = var.region
}

# S3 bucket that stores terraform.tfstate for the EKS root.
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Safety: do not let `terraform destroy` here nuke the state bucket by accident.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    purpose = "terraform-state"
    project = "kube-pilots"
  }
}

# Keep every version of the state file so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (state can contain secrets).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking (prevents two applies at once).
resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    purpose = "terraform-state-lock"
    project = "kube-pilots"
  }
}
