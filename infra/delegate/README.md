# Harness Delegate — kube-pilot

Installs the Harness Kubernetes delegate onto the `kube-pilot` EKS cluster so the
Preflight K8s upgrade agent can drive the cluster through Harness.

- Harness account: `gLXLxjTmQhGmdJXhAORKag`
- Org / project: `Worker_Agents_Hackathon` / `Team_KubePilots`
- Delegate name: `helm-delegate`
- Namespace: `harness-delegate-ng`

## Files

```
values.yaml    Helm values (account, org/project, name, image) — NO token
install.sh     helm upgrade --install; reads token from HARNESS_DELEGATE_TOKEN
.gitignore     blocks any local token/secret files from being committed
```

The delegate token is a **secret** and is never stored in this repo. It is passed
at install time via the `HARNESS_DELEGATE_TOKEN` environment variable.

## Prerequisites

- `kubectl` pointed at `kube-pilot` with a valid MFA AWS session
  (`$env:AWS_PROFILE = "avyka-mfa"`; re-mint if expired)
- `helm`
- A delegate token from the Harness project
  (Team_KubePilots -> Settings -> Delegates -> New Delegate, or Delegate Tokens)

## Install

```bash
export HARNESS_DELEGATE_TOKEN='<token from Harness UI>'
./install.sh
```

Or run the Helm command directly:

```bash
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update

helm upgrade -i helm-delegate harness-delegate/harness-delegate-ng \
  --namespace harness-delegate-ng --create-namespace \
  --set delegateName=helm-delegate \
  --set accountId=gLXLxjTmQhGmdJXhAORKag \
  --set delegateToken="$HARNESS_DELEGATE_TOKEN" \
  --set managerEndpoint=https://app.harness.io \
  --set delegateDockerImage=us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:26.10.90208 \
  --set replicas=1 --set upgrader.enabled=true
```

## Verify

```bash
kubectl -n harness-delegate-ng rollout status deploy/helm-delegate
kubectl -n harness-delegate-ng get pods
```

Then confirm the delegate shows **Connected** in the Harness UI under
Team_KubePilots -> Delegates.

## Notes

- The delegate needs cluster permissions to drive an upgrade; the Helm chart
  creates its own service account and RBAC.
- `upgrader.enabled=true` installs a CronJob that keeps the delegate image
  auto-updated.
