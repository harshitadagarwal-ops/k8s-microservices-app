#!/usr/bin/env bash
# Install / upgrade the Harness delegate on the current kubectl context
# (kube-pilot EKS cluster).
#
# The delegate token is a SECRET and is NOT stored in this repo. Export it first:
#
#   export HARNESS_DELEGATE_TOKEN='<token from Harness UI>'
#   ./install.sh
#
# Get the token from the Harness project:
#   org Worker_Agents_Hackathon / project Team_KubePilots
#   Settings -> Delegates -> New Delegate (Kubernetes / Helm), or Delegate Tokens.

set -euo pipefail

: "${HARNESS_DELEGATE_TOKEN:?Set HARNESS_DELEGATE_TOKEN before running (not committed to Git)}"

ACCOUNT_ID="gLXLxjTmQhGmdJXhAORKag"
MANAGER_ENDPOINT="https://app.harness.io"
DELEGATE_IMAGE="us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:26.10.90208"
DELEGATE_NAME="helm-delegate"
NAMESPACE="harness-delegate-ng"

helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/ 2>/dev/null || true
helm repo update harness-delegate

helm upgrade -i "${DELEGATE_NAME}" harness-delegate/harness-delegate-ng \
  --namespace "${NAMESPACE}" --create-namespace \
  --set delegateName="${DELEGATE_NAME}" \
  --set accountId="${ACCOUNT_ID}" \
  --set delegateToken="${HARNESS_DELEGATE_TOKEN}" \
  --set managerEndpoint="${MANAGER_ENDPOINT}" \
  --set delegateDockerImage="${DELEGATE_IMAGE}" \
  --set replicas=1 \
  --set upgrader.enabled=true

echo
echo "Submitted. Watch it come up:"
echo "  kubectl -n ${NAMESPACE} rollout status deploy/${DELEGATE_NAME}"
echo "Then confirm it shows Connected in the Harness UI (Team_KubePilots -> Delegates)."
