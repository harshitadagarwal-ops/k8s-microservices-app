#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for the on-premise local Kind demo environment.
# Sets up kind cluster pinned to v1.32.0 (containerd 1.7) and initializes Argo CD.
# Does NOT execute destructive upgrades or touch real cloud infrastructure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="preflight-onprem"

echo "=== [1/4] Checking prerequisites ==="
command -v kind >/dev/null 2>&1 || { echo >&2 "kind is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required but not installed. Aborting."; exit 1; }

echo "=== [2/4] Creating local Kind cluster (${CLUSTER_NAME}) on K8s 1.32 ==="
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Reusing existing cluster."
else
  kind create cluster --name "${CLUSTER_NAME}" --config "${REPO_ROOT}/infra/onprem/kind-config.yaml"
fi

kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo "=== [3/4] Installing Argo CD v2.14.0 (Planted F05) ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k "${REPO_ROOT}/platform/argocd" -n argocd

echo "=== [4/4] Deploying platform and application manifests ==="
kubectl apply -f "${REPO_ROOT}/argocd/onprem/apps.yaml"

echo ""
echo "=== Bootstrap Complete ==="
echo "Live Findings Active:"
echo " - F02: FlowControl v1beta3 sync failure visible in Argo CD / kubectl"
echo " - F03: Containerd 1.7 runtime active on nodes"
echo " - F07: Legacy Endpoints reporter CronJob running every 5 min"
echo " - F08 & F09: MySQL single-replica PDB and emptyDir storage mounted"
