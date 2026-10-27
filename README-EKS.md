# K8s Microservices — EKS Runbook

The same 3-tier demo app as the [Minikube runbook](README.md), deployed on a real
**Amazon EKS** cluster (`kube-pilot`, Kubernetes 1.32).

```
Internet ──> ALB (Ingress) ──> frontend (Flask) ──> backend (Flask REST API) ──> mysql (MySQL, EBS gp3)
```

What differs from the Minikube version:

| | Minikube | EKS |
|---|----------|-----|
| Images | built into Minikube's Docker | pushed to **Amazon ECR** |
| Frontend access | `NodePort` + `minikube service` | **ALB Ingress** (public URL) |
| MySQL storage | `emptyDir` (data lost on restart) | **EBS gp3 PVC** (persists) |
| Cluster | local single node | managed EKS, 2 nodes |

The cluster itself is provisioned by Terraform in [`infra/eks/`](infra/eks/README.md).
This runbook covers deploying the **app** onto that cluster.

---

## Prerequisites

- The `kube-pilot` EKS cluster is already created (see `infra/eks/`).
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/) (used to build the images; on this
  machine Docker runs inside WSL)
- ECR permissions: `ecr:CreateRepository`, `ecr:InitiateLayerUpload`,
  `ecr:PutImage`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` (plus the
  read/auth actions). The hackathon user may need these granted first.

### Account / region

- Account: `105673693246`
- Region: `us-east-1`

### Authenticate (MFA required on this account)

The Avyka account denies everything without an MFA-authenticated session. Mint a
session token and use it as a profile (valid 12h):

```powershell
aws sts get-session-token `
  --serial-number arn:aws:iam::105673693246:mfa/<your-mfa-device> `
  --token-code <6-digit-code> `
  --duration-seconds 43200
# then set the returned values into a profile, e.g. "avyka-mfa"
$env:AWS_PROFILE = "avyka-mfa"
aws sts get-caller-identity          # should show 105673693246
```

### Point kubectl at the cluster

```powershell
aws eks update-kubeconfig --name kube-pilot --region us-east-1
kubectl get nodes                    # nodes should be Ready
```

---

## Step-by-step deploy

### 1. ECR repositories

The ECR repos are **Terraform-managed** (`infra/eks/ecr.tf`) and created with the
rest of the infra via `terraform apply` in `infra/eks/`. You do not normally
create them by hand.

If you ever need to create them manually (e.g. in a fresh account before running
Terraform), the equivalent CLI is:
```powershell
aws ecr create-repository --repository-name three-tier/frontend --region us-east-1
aws ecr create-repository --repository-name three-tier/backend  --region us-east-1
```

Capture your registry host (used below):
```powershell
$ACCOUNT = aws sts get-caller-identity --query Account --output text
$REGISTRY = "$ACCOUNT.dkr.ecr.us-east-1.amazonaws.com"
```

### 2. Build and push the images

> Docker runs in WSL on this machine, so the build/push commands run through `wsl`.
> The repo path inside WSL is under `/mnt/c/...`.

Log in to ECR, then build and push both images:
```bash
# inside WSL, from the repo root
AWS_PROFILE=avyka-mfa aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    105673693246.dkr.ecr.us-east-1.amazonaws.com

docker build -t 105673693246.dkr.ecr.us-east-1.amazonaws.com/three-tier/backend:latest  ./backend
docker build -t 105673693246.dkr.ecr.us-east-1.amazonaws.com/three-tier/frontend:latest ./frontend

docker push 105673693246.dkr.ecr.us-east-1.amazonaws.com/three-tier/backend:latest
docker push 105673693246.dkr.ecr.us-east-1.amazonaws.com/three-tier/frontend:latest
```

### 3. Deploy everything with Kustomize

Deployment is a single command. `manifests-eks/kustomization.yaml` pulls in the
shared base (`manifests/` namespace + config/secret) and sets the ECR registry on
the images via an `images:` transformer — so there's no placeholder to edit and
no manual substitution.

```powershell
kubectl apply -k manifests-eks/
```

To deploy to a **different** account/region, edit the `images:` `newName` values
in `manifests-eks/kustomization.yaml` (one place) — the deployment YAMLs keep
plain base image names and don't change.

> The Minikube runbook still uses `kubectl apply -f manifests/` for its flow;
> that ignores the kustomization files, so both workflows coexist.

### 4. Watch it come up
```powershell
kubectl get pods -n demo -w
# Wait until all pods are Running / READY  (MySQL takes ~30-60s the first time)
```

```powershell
kubectl get pvc -n demo          # mysql-data should be Bound (EBS volume)
kubectl get ingress -n demo      # ADDRESS fills in with the ALB DNS name (~2-3 min)
```

### 5. Open the app
```powershell
kubectl get ingress frontend -n demo -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```
Open that `http://<alb-dns-name>/` in your browser. Add a message; it's saved in
MySQL via the backend. Because MySQL uses an EBS PVC, the data survives pod
restarts (unlike the Minikube emptyDir version).

---

## Live teaching moments

**Self-healing** — delete a pod and watch the Deployment recreate it:
```powershell
kubectl delete pod -l app=backend -n demo
kubectl get pods -n demo
```

**Scaling**:
```powershell
kubectl scale deployment backend --replicas=4 -n demo
kubectl get pods -n demo
```

**Persistence proof** — delete the MySQL pod, confirm messages survive:
```powershell
kubectl delete pod -l app=mysql -n demo
# after it restarts, refresh the app — your messages are still there (EBS volume)
```

**Inspecting**:
```powershell
kubectl describe ingress frontend -n demo       # ALB details, target health
kubectl logs deploy/backend -n demo
kubectl get all -n demo
```

---

## Cleanup

Remove the app (keeps the cluster):
```powershell
kubectl delete -k manifests-eks/
```
Deleting the frontend Ingress removes the ALB. Deleting the mysql PVC releases
the EBS volume.

Tear down the whole cluster (from `infra/eks/`):
```powershell
terraform destroy
```
> Note: this user can't delete IAM roles, so `terraform destroy` may leave the
> cluster's IAM roles behind for an admin to remove. The cluster, VPC, nodes, and
> load balancers are removed normally.

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Pods stuck `ImagePullBackOff` | Registry wrong in `manifests-eks/kustomization.yaml` `images:`, or image not pushed. Recheck step 2 and the kustomization. |
| `AccessDenied` on ECR push | Missing `ecr:*` push permissions on your user (see Prerequisites / `infra/eks/admin-permissions-request.json`). |
| Ingress `ADDRESS` stays empty | AWS Load Balancer Controller issue: `kubectl logs -n kube-system deploy/aws-load-balancer-controller`. |
| PVC stuck `Pending` | EBS CSI driver / gp3 StorageClass missing: `kubectl get storageclass`. |
| `kubectl` auth errors | MFA session expired — re-mint the session token (see Authenticate). |
| Backend returns **500** on `/api/messages`; logs show `'cryptography' package is required for ... caching_sha2_password` | MySQL 8.0 uses `caching_sha2_password` auth, which PyMySQL can't do without the `cryptography` package. It is in `backend/requirements.txt`; if you see this, rebuild/push the backend image and `kubectl rollout restart deployment/backend -n demo`. |

---

## Cost saving: scale nodes to zero when idle

The EKS control plane and NAT gateway bill ~$0.15/hr regardless, but you can stop
the **node (EC2) charges** overnight by scaling the managed node group to 0, then
back up when you resume. The cluster, PVCs, and load balancer config are preserved.

```powershell
$NG = aws eks list-nodegroups --cluster-name kube-pilot --region us-east-1 --query "nodegroups[0]" --output text

# scale DOWN (end of day)
aws eks update-nodegroup-config --cluster-name kube-pilot --nodegroup-name $NG `
  --scaling-config minSize=0,maxSize=3,desiredSize=0 --region us-east-1

# scale UP (resume) — then pods (incl. the Harness delegate) reschedule automatically
aws eks update-nodegroup-config --cluster-name kube-pilot --nodegroup-name $NG `
  --scaling-config minSize=2,maxSize=3,desiredSize=2 --region us-east-1
```

> Doing this via CLI causes Terraform drift (state still says desired=2). A later
> `terraform apply` reconciles it — expected, not harmful.
