variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the state bucket and lock table."
}

variable "state_bucket_name" {
  type        = string
  default     = "kube-pilot-tfstate-105673693246-use1"
  description = "Globally-unique S3 bucket name for Terraform state. Account ID is baked in to avoid collisions."
}

variable "lock_table_name" {
  type        = string
  default     = "kube-pilot-tflock"
  description = "DynamoDB table name for Terraform state locking."
}
