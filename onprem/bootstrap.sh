#!/usr/bin/env bash
# Builds the onprem cluster on this VM: kind cluster, app images, Argo CD, Applications.
#
# Usage: onprem/bootstrap.sh [--recreate] [--revision <git-branch>]
#   --recreate   delete the existing cluster first
#   --revision   branch Argo CD tracks for this repo (default: main)
#
# Requires: docker, kind, kubectl.
set -euo pipefail

KIND_VERSION="v0.26.0"
CLUSTER_NAME="preflight-onprem"
KUBECONFIG_OUT="${HOME}/.kube/${CLUSTER_NAME}"
REVISION="main"
RECREATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --recreate) RECREATE=true; shift ;;
    --revision) REVISION="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

for bin in docker kind kubectl; do
  command -v "$bin" >/dev/null || { echo "missing: $bin" >&2; exit 1; }
done

if ! kind version | grep -q "${KIND_VERSION}"; then
  echo "kind ${KIND_VERSION} is required, found: $(kind version)" >&2
  echo "install: https://github.com/kubernetes-sigs/kind/releases/tag/${KIND_VERSION}" >&2
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  if $RECREATE; then
    echo "==> deleting cluster ${CLUSTER_NAME}"
    kind delete cluster --name "${CLUSTER_NAME}"
  else
    echo "cluster ${CLUSTER_NAME} already exists (use --recreate to rebuild)" >&2
    exit 1
  fi
fi

echo "==> creating cluster ${CLUSTER_NAME}"
RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT
sed "s|__REPO_ROOT__|${REPO_ROOT}|g" onprem/kind-config.yaml > "${RENDERED}"
mkdir -p "$(dirname "${KUBECONFIG_OUT}")"
kind create cluster --config "${RENDERED}" --kubeconfig "${KUBECONFIG_OUT}" --wait 120s
export KUBECONFIG="${KUBECONFIG_OUT}"

echo "==> building and loading app images"
docker build -t frontend:1.0.0 frontend/
docker build -t backend:1.0.0 backend/
kind load docker-image frontend:1.0.0 backend:1.0.0 --name "${CLUSTER_NAME}"

echo "==> installing Argo CD"
kubectl apply -k platform/argocd-install --server-side --force-conflicts
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> registering Applications (tracking ${REVISION})"
sed "s|targetRevision: main|targetRevision: ${REVISION}|" gitops/onprem/apps.yaml | kubectl apply -f -

echo
echo "Cluster ready. KUBECONFIG=${KUBECONFIG_OUT}"
echo "Applications:  kubectl -n argocd get applications"
echo "Argo CD admin: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
