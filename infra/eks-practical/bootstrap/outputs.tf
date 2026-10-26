output "state_bucket_name" {
  value       = aws_s3_bucket.tfstate.id
  description = "Name of the S3 bucket holding Terraform state. Use this in the main root's backend \"s3\" block."
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tflock.name
  description = "Name of the DynamoDB lock table. Use this in the main root's backend \"s3\" block."
}

output "region" {
  value       = var.region
  description = "Region the state bucket and lock table live in."
}
