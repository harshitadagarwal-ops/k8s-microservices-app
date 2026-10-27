# kube-pilot — EKS

Deployable EKS 1.32 cluster for the kube-pilot estate. Creates its own VPC,
a managed node group, the EBS CSI driver (for PVCs) and the AWS Load Balancer
Controller (for Ingress / LoadBalancer services). All inputs come from
`terraform.tfvars`.

## Layout

```
bootstrap/        S3 state bucket + DynamoDB lock table (LOCAL state). Run once.
versions.tf       providers (aws, kubernetes, helm) + S3 backend
vpc.tf            VPC (2 AZs, public + private subnets, single NAT)
eks.tf            EKS 1.32 cluster, AL2023 nodes, EBS CSI driver, gp3 StorageClass
loadbalancer.tf   AWS Load Balancer Controller + its IRSA role
variables.tf      inputs
terraform.tfvars  values (region, versions, node sizes, toggles)
outputs.tf        cluster endpoint / name / kubeconfig command
```

## Target account / region

- Account: `105673693246` (Avyka)
- Region: `us-east-1` (the account is restricted to a single region)
- Requires an MFA-authenticated session (guardrail `IAM-Guardrail-EnforceMFA-SelfService`)

## Deploy

**1. MFA session (required by the account guardrail):**
```powershell
aws sts get-session-token --serial-number arn:aws:iam::105673693246:mfa/<device> --token-code <6-digit>
# export the returned creds as AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
aws sts get-caller-identity   # should show 105673693246
```

**2. Bootstrap the state backend (once):**
```powershell
cd bootstrap
terraform init
terraform apply
cd ..
```

**3. Deploy the cluster:**
```powershell
terraform init
terraform plan
terraform apply
```
EKS creation takes ~15 minutes.

**4. Connect kubectl:**
```powershell
aws eks update-kubeconfig --name kube-pilot --region us-east-1
kubectl get nodes
```

## What you get for load balancing

- The **AWS Load Balancer Controller** is installed in `kube-system`.
- Create a Kubernetes `Ingress` (class `alb`) and it provisions an **ALB**.
- Create a `Service` of `type: LoadBalancer` with NLB annotations and it
  provisions an **NLB**.

## Cost

Billable while running (us-east-1, approx): EKS control plane ~$0.10/hr,
NAT gateway ~$0.045/hr, 2x t3.medium ~$0.08/hr, plus any ALB/NLB the apps
create. Tear down with `terraform destroy` when done.
