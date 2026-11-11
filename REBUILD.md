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

## Teardown leftovers (as of last destroy)

The destroy removed ALL billable resources (EKS cluster, nodes, NAT, ALB, EBS).
Two harmless (free) leftovers remain because this user can't delete IAM / and the
ECR repos are intentionally kept:

- **IAM roles/policies + OIDC provider** (kube-pilot-*, general-eks-node-group-*).
  Free. `terraform destroy` can't remove them (iam:DetachRolePolicy denied).
  They may get reused on rebuild, or an admin can delete them.
- **Leftover VPC** `vpc-0351908d457ff85fc` with 2 private subnets. Free (no NAT/EIP).
  BEFORE rebuild, either delete it manually (subnets -> route tables -> vpc) OR
  let `terraform apply` create a fresh VPC (may need the old one gone first to
  avoid CIDR/name conflicts). Terraform state no longer references most resources,
  so a clean `terraform apply` should recreate everything.
- **ECR repos kept** (three-tier/frontend, three-tier/backend) with multi-arch
  images — reused on rebuild, no image rebuild needed.

## Notes / gotchas
- Nightly `avyka-management-auto-stop` scales the node group to 0 (~20:00 IST).
  Scale back up: `aws eks update-nodegroup-config --cluster-name kube-pilot
  --nodegroup-name <ng> --scaling-config minSize=2,maxSize=3,desiredSize=2 --region us-east-1`
- Graviton requires arm64 images (app images are already multi-arch).
- Node pool is Spot: restricted to >=2 vCPU types so the delegate (cpu:1) fits.
- IAM delete is NOT granted to this user, so `terraform destroy` may leave IAM
  roles/OIDC behind — an admin cleans those, or they get reused on rebuild.

## Rebuild #2 learnings (IAM limits) — READ BEFORE THE NEXT REBUILD

This user can CREATE IAM roles/OIDC providers but cannot DELETE them or UPDATE
role trust policies (`iam:DeleteOpenIDConnectProvider`, `iam:UpdateAssumeRolePolicy`,
`iam:DetachRolePolicy` are not granted). A new cluster gets a NEW OIDC issuer URL,
so a plain `terraform apply` after a destroy plans to REPLACE the OIDC provider and
UPDATE the two IRSA role trust policies — both of which fail with AccessDenied.

What was done on rebuild #2 (worked, plan was 36 add / 0 change / 0 destroy):

1. Back up state: `terraform state pull > $env:TEMP\kube-pilot-state-backup.json`
   (the S3 state bucket is also versioned).
2. Forget the stale IAM objects (they stay in AWS as free orphans):
   ```powershell
   terraform state rm 'module.eks.aws_iam_openid_connect_provider.oidc_provider[0]' `
     'module.ebs_csi_irsa.aws_iam_role.this[0]' `
     'module.ebs_csi_irsa.aws_iam_role_policy_attachment.ebs_csi[0]' `
     'module.lb_controller_irsa[0].aws_iam_role.this[0]' `
     'module.lb_controller_irsa[0].aws_iam_role_policy_attachment.load_balancer_controller[0]'
   ```
3. Bump the IRSA role names so the create doesn't collide with the orphans
   (`eks.tf` / `loadbalancer.tf`): currently `-ebs-csi-v2` and `-lb-controller-v2`.
   The NEXT rebuild must bump again (`-v3`) and repeat step 2 for the v2 objects.
4. `terraform plan "-out=rebuild.tfplan"` — quote `-out=` in PowerShell, otherwise it
   fails with "Too many command line arguments". Confirm 0 change / 0 destroy.
5. `terraform apply rebuild.tfplan`.

Permanent fix: ask an admin to grant `iam:DeleteOpenIDConnectProvider` and
`iam:UpdateAssumeRolePolicy` (narrow, much safer than full IAM delete), after which
a normal `terraform destroy` / `apply` cycle works with no state surgery.

Other notes from this rebuild:
- The leftover VPC + private subnets + security groups from the previous destroy were
  REUSED by Terraform automatically (still in state) — no manual VPC cleanup needed.
  This supersedes the "delete the VPC first" advice in the section above.
- Before `terraform destroy`, delete the app Ingress first (`kubectl delete -k
  manifests-eks/`) so the AWS LB Controller removes the ALB. A stray ALB holds ENIs in
  the public subnets and makes the subnet/IGW destroy hang.
- The Harness K8s connector (`kube-pilot-avyka-eks`) uses the delegate's in-cluster
  identity, so it needs no endpoint changes after a rebuild — just re-test it.
- The ALB DNS name changes on every rebuild: `kubectl get ingress -n demo`.
