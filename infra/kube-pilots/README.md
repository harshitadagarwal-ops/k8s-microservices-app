# EKS 1.32 Practical

A self-contained, deployable EKS 1.32 cluster for hands-on practice. Unlike
`infra/eks/` (the Preflight analysis fixture, which assumes a pre-existing VPC,
uses a private-only endpoint, and points at a placeholder S3 bucket), this root
creates its own VPC and is reachable from your laptop.

## Layout

```
bootstrap/        S3 state bucket + DynamoDB lock table (LOCAL state). Run once.
versions.tf       providers + S3 backend
vpc.tf            VPC (2 AZs, public + private subnets, single NAT)
eks.tf            EKS 1.32 cluster, AL2023 nodes, EBS CSI driver, gp3 StorageClass
variables.tf      inputs (region, cluster_version, node sizes, ...)
terraform.tfvars  default values for a practical
outputs.tf        cluster endpoint / name / kubeconfig command
```

## Prerequisites

- AWS credentials with permission to create VPC / EKS / IAM / S3 / DynamoDB
- Terraform >= 1.6, AWS CLI v2, kubectl

Verify who you are:
```powershell
aws sts get-caller-identity
```

## Deploy

**1. Bootstrap the state backend (once per account):**
```powershell
cd bootstrap
terraform init
terraform apply
cd ..
```

**2. Deploy the cluster:**
```powershell
terraform init
terraform plan
terraform apply
```
EKS creation takes ~15 minutes.

**3. Connect kubectl:**
```powershell
aws eks update-kubeconfig --name kube-pilots --region eu-west-1
kubectl get nodes
```

## Cost

Billable while running (eu-west-1, approx):
- EKS control plane: ~$0.10/hr
- NAT gateway: ~$0.045/hr + data
- 2 x t3.medium nodes: ~$0.08/hr

Roughly $0.25-0.30/hr. Tear down when done:
```powershell
terraform destroy
```
(The state bucket in `bootstrap/` has `prevent_destroy`; delete it manually only
if you are abandoning the account.)

## Moving to another AWS account

State is per-account; a cluster cannot be migrated between accounts. To rebuild
in a different account:

1. In `bootstrap/variables.tf` set `state_bucket_name` to include the new
   account ID (bucket names are globally unique).
2. In `versions.tf` update the `backend "s3"` `bucket` to match.
3. Re-run both steps above with credentials for the new account.
4. `terraform destroy` the old account when you no longer need it.
