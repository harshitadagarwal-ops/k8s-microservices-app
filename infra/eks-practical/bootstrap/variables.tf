variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region for the state bucket and lock table."
}

variable "state_bucket_name" {
  type        = string
  default     = "kube-pilots-tfstate-058264184834-euw1"
  description = "Globally-unique S3 bucket name for Terraform state. Account ID is baked in to avoid collisions."
}

variable "lock_table_name" {
  type        = string
  default     = "kube-pilots-tflock"
  description = "DynamoDB table name for Terraform state locking."
}
