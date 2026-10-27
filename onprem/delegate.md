# Harness delegate for the onprem cluster

The delegate runs as a **Docker container on the VM**, not as a pod inside the kind cluster. `bootstrap.sh --recreate` deletes and rebuilds the cluster; a delegate running inside it would be deleted too.

## Run

1. Build the cluster first (`onprem/bootstrap.sh`). It writes the kubeconfig to `~/.kube/preflight-onprem`. The API server listens on the fixed address `127.0.0.1:6443`, so this file stays valid across rebuilds.

2. Start the delegate with host networking so it can reach `127.0.0.1:6443`:

   ```bash
   docker run -d --name harness-delegate-onprem --restart unless-stopped \
     --network host \
     --cpus=1 --memory=2g \
     -e DELEGATE_NAME=onprem-delegate \
     -e DELEGATE_TAGS=onprem-k8s \
     -e NEXT_GEN=true \
     -e DELEGATE_TYPE=DOCKER \
     -e ACCOUNT_ID=<harness-account-id> \
     -e DELEGATE_TOKEN=<delegate-token> \
     -e MANAGER_HOST_AND_PORT=https://app.harness.io \
     -e KUBECONFIG=/opt/harness-delegate/.kube/config \
     -v "$HOME/.kube/preflight-onprem:/opt/harness-delegate/.kube/config:ro" \
     harness/delegate:<version>
   ```

   Take the token and image version from **Project Settings → Delegates → New Delegate → Docker** in Harness. Never commit the token.

   Host networking is Linux-only. On Docker Desktop, set `apiServerAddress` in `kind-config.yaml` to the VM's address instead.

## Connectors

| Connector | Type | Points at | Delegate selector |
|---|---|---|---|
| `onprem-k8s-connector` | Kubernetes | "Use the credentials of a specific Harness Delegate" | `onprem-k8s` |
| `onprem-git` (and the cloud envs' Git connectors) | GitHub | this repo | `onprem-k8s` |

The cloud environments (`prod-eks`, `staging-gke`, `dev-aks`) have no cluster. They only need a Git connector, which can use the same delegate.

## Rebuilding the cluster

```bash
onprem/bootstrap.sh --recreate
docker restart harness-delegate-onprem   # picks up the new cluster credentials
```
