# Rebuild Runbook — kube-pilot EKS + app + delegate

Everything needed to recreate the full environment after a `terraform destroy`.
The infra is Terraform-managed and the app/RBAC are tracked manifests, so rebuild
is reproducible from this repo.

## What gets destroyed vs. what survives

Destroyed by `terraform destroy` (in `infra/eks/`):
- EKS cluster `kube-pilot`, node group, VPC/subnets/NAT, IAM roles, OIDC, add-ons,
  AWS Load Balancer Controller.

Survives (NOT destroyed):
- **S3 state bucket** `kube-pilot-tfstate-105673693246-use1` + DynamoDB lock table
  (bootstrap, has `prevent_destroy`). Reused on rebuild.
- **ECR repos** `three-tier/frontend` + `three-tier/backend` and the pushed
  **multi-arch (amd64+arm64) images**. Reused on rebuild — no need to rebuild
  images unless code changed.
- Everything in this git repo.

## Key facts to reuse

- Account: `105673693246` (Avyka), region: `us-east-1`
- Cluster: `kube-pilot`, Kubernetes `1.34`
- Nodes: Graviton (ARM) + Spot, instance pool >=2 vCPU (see terraform.tfvars)
- ECR registry: `105673693246.dkr.ecr.us-east-1.amazonaws.com`
- Harness: org `Worker_Agents_Hackathon`, project `Team_KubePilots`,
  delegate `helm-delegate`, namespace `harness-delegate-ng`
- Preflight CI SA: `preflight-readonly` in `harness-preflight`

## Rebuild steps (tomorrow)

### 0. MFA session
```powershell
aws sts get-session-token --serial-number arn:aws:iam::105673693246:mfa/harshita-iphone --token-code <CODE> --duration-seconds 43200 --profile default --output json
# save AccessKeyId/SecretAccessKey/SessionToken into profile avyka-mfa, region us-east-1
$env:AWS_PROFILE = "avyka-mfa"
```

### 1. Recreate the cluster (Terraform)
```powershell
cd infra/eks
terraform init      # backend bucket still exists
terraform apply     # ~15 min: VPC + EKS 1.34 + Graviton/Spot nodes + addons + LB controller
aws eks update-kubeconfig --name kube-pilot --region us-east-1
kubectl get nodes
```

### 2. Reinstall the Harness delegate
```powershell
export HARNESS_DELEGATE_TOKEN='<token from Harness UI: Team_KubePilots -> Delegates>'
cd ../delegate ; ./install.sh      # or the helm upgrade command in infra/delegate/README.md
```

### 3. Preflight read-only RBAC (for the pipeline's CI pod)
```powershell
kubectl apply -f manifests-eks/preflight-readonly-rbac.yaml
```

### 4. Deploy the app (images already in ECR; multi-arch)
```powershell
kubectl apply -k manifests-eks/
kubectl get pods -n demo -w
kubectl get ingress -n demo        # ALB DNS appears in ~2-3 min
```
If app code changed, rebuild images first: `bash build-push-arm.sh` (multi-arch).

### 5. Harness pipeline
Pipeline/input-set YAML is in `harness/`. Reconnect connectors if needed; the
cluster endpoint is stable (same cluster name) but the API server cert/endpoint
changes on recreate, so the Kubernetes connector may need a re-test.

## Notes / gotchas
- Nightly `avyka-management-auto-stop` scales the node group to 0 (~20:00 IST).
  Scale back up: `aws eks update-nodegroup-config --cluster-name kube-pilot
  --nodegroup-name <ng> --scaling-config minSize=2,maxSize=3,desiredSize=2 --region us-east-1`
- Graviton requires arm64 images (app images are already multi-arch).
- Node pool is Spot: restricted to >=2 vCPU types so the delegate (cpu:1) fits.
- IAM delete is NOT granted to this user, so `terraform destroy` may leave IAM
  roles/OIDC behind — an admin cleans those, or they get reused on rebuild.
