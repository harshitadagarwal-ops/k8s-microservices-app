# ECR repositories for the three-tier app images.
# Created out-of-band earlier and imported into Terraform so they are now
# managed as code (see README / terraform import commands).

locals {
  ecr_repos = ["three-tier/frontend", "three-tier/backend"]
}

resource "aws_ecr_repository" "app" {
  for_each = toset(local.ecr_repos)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# Keep only the last N untagged images to control storage cost.
resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "ecr_repository_urls" {
  value       = { for k, r in aws_ecr_repository.app : k => r.repository_url }
  description = "ECR repository URLs for the app images."
}
