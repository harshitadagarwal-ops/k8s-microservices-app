#!/usr/bin/env bash
# Proves the planted findings behave as described in preflight/EXPECTED_FINDINGS.md.
# Some checks EXPECT a failure (the finding is real); the script fails if they pass.
#
# Usage: ci/validate.sh
# Env:
#   SKIP_TERRAFORM=1        skip terraform init/validate (needs network)
#   SKIP_REMOTE=1           skip builds that fetch remote resources (Argo CD install)
#   TARGET_SCHEMA=1.33.0    newest kubeconform schema to test against (if kubeconform is installed)
#   PREFLIGHT_REPORT=path   agent output JSON; checks that no evidence comes from ignored paths
#
# Requires: helm, kubectl (for `kubectl kustomize`). Optional: kubeconform, terraform, jq.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

ENVS=(onprem prod-eks staging-gke dev-aks)
SCANNED_PATHS=(charts platform gitops infra onprem)
TARGET_SCHEMA="${TARGET_SCHEMA:-1.33.0}"
OUT="$(mktemp -d)"
trap 'rm -rf "${OUT}"' EXIT

pass=0; fail=0
ok()   { echo "  PASS  $*"; pass=$((pass + 1)); }
bad()  { echo "  FAIL  $*"; fail=$((fail + 1)); }
skip() { echo "  SKIP  $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# group/version -> first Kubernetes minor where it is no longer served
REMOVED_APIS=(
  "extensions/v1beta1 1.22"
  "networking.k8s.io/v1beta1 1.22"
  "batch/v1beta1 1.25"
  "policy/v1beta1 1.25"
  "autoscaling/v2beta1 1.25"
  "autoscaling/v2beta2 1.26"
  "flowcontrol.apiserver.k8s.io/v1beta1 1.26"
  "storage.k8s.io/v1beta1 1.27"
  "flowcontrol.apiserver.k8s.io/v1beta2 1.29"
  "flowcontrol.apiserver.k8s.io/v1beta3 1.32"
)

# Prints removed apiVersions found in file $1 for cluster minor $2 (e.g. 32).
removed_in() {
  local file="$1" minor="$2" entry gv at
  for entry in "${REMOVED_APIS[@]}"; do
    gv="${entry% *}"; at="${entry#* }"; at="${at#1.}"
    if (( minor >= at )) && grep -qE "^apiVersion: ${gv//./\\.}\$" "$file"; then
      echo "$gv"
    fi
  done
}

echo "== Helm chart"
for env in "${ENVS[@]}"; do
  f="${OUT}/chart-${env}.yaml"
  if helm template three-tier charts/three-tier -f charts/three-tier/values.yaml \
       -f "charts/three-tier/values-${env}.yaml" --kube-version 1.32.0 >"$f" 2>"${OUT}/err"; then
    ok "chart renders for ${env} on 1.32"
  else
    bad "chart does not render for ${env} on 1.32: $(cat "${OUT}/err")"
  fi
done

if helm template three-tier charts/three-tier --kube-version 1.34.0 >/dev/null 2>"${OUT}/err"; then
  bad "chart renders on 1.34, expected kubeVersion to refuse it"
elif grep -q "kubeVersion" "${OUT}/err"; then
  ok "chart refuses to render on 1.34 (kubeVersion constraint)"
else
  bad "chart fails on 1.34 for an unexpected reason: $(cat "${OUT}/err")"
fi

echo "== Kustomize builds"
build() { kubectl kustomize "$1" >"$2" 2>"${OUT}/err"; }

for env in "${ENVS[@]}"; do
  f="${OUT}/flowcontrol-${env}.yaml"
  if ! build "platform/flowcontrol/overlays/${env}" "$f"; then
    bad "flowcontrol/${env} does not build: $(cat "${OUT}/err")"; continue
  fi
  found="$(removed_in "$f" 32)"
  if [[ -n "$found" ]]; then
    ok "flowcontrol/${env} uses APIs not served on 1.32: ${found//$'\n'/, }"
  else
    bad "flowcontrol/${env} expected to use an API removed by 1.32"
  fi
done

f="${OUT}/service-inventory.yaml"
if build platform/service-inventory/overlays/onprem "$f"; then
  ok "service-inventory/onprem builds"
  if grep -qE '^\s*- "?endpoints"?$' "$f" && grep -q '/api/v1/endpoints' "$f"; then
    ok "service-inventory reads core/v1 Endpoints (RBAC + client call)"
  else
    bad "service-inventory expected to read core/v1 Endpoints"
  fi
else
  bad "service-inventory/onprem does not build: $(cat "${OUT}/err")"
fi

if [[ "${SKIP_REMOTE:-0}" == 1 ]]; then
  skip "argocd-install (SKIP_REMOTE=1)"
elif build platform/argocd-install "${OUT}/argocd.yaml"; then
  ok "argocd-install builds (Argo CD v2.14.0)"
else
  bad "argocd-install does not build: $(cat "${OUT}/err")"
fi

echo "== Removed APIs outside flowcontrol (1.32 and 1.36)"
for f in "${OUT}"/chart-*.yaml "${OUT}/service-inventory.yaml"; do
  [[ -s "$f" ]] || continue
  for minor in 32 36; do
    found="$(removed_in "$f" "$minor")"
    if [[ -n "$found" ]]; then bad "$(basename "$f") uses APIs removed by 1.${minor}: ${found}"
    else ok "$(basename "$f") has no APIs removed by 1.${minor}"; fi
  done
done

echo "== kubeconform"
if have kubeconform; then
  for ver in 1.32.0 "${TARGET_SCHEMA}"; do
    for f in "${OUT}"/chart-*.yaml "${OUT}/service-inventory.yaml"; do
      [[ -s "$f" ]] || continue
      if kubeconform -strict -summary -kubernetes-version "$ver" "$f" >"${OUT}/err" 2>&1; then
        ok "$(basename "$f") valid against ${ver} schemas"
      else
        bad "$(basename "$f") invalid against ${ver} schemas: $(tail -3 "${OUT}/err")"
      fi
    done
    for env in "${ENVS[@]}"; do
      f="${OUT}/flowcontrol-${env}.yaml"
      if kubeconform -strict -kubernetes-version "$ver" "$f" >/dev/null 2>&1; then
        bad "flowcontrol/${env} unexpectedly valid against ${ver} schemas"
      else
        ok "flowcontrol/${env} rejected by ${ver} schemas"
      fi
    done
  done
else
  skip "kubeconform not installed (removed-API table above still ran)"
fi

echo "== Terraform"
if [[ "${SKIP_TERRAFORM:-0}" == 1 ]]; then
  skip "terraform (SKIP_TERRAFORM=1)"
elif have terraform; then
  for d in infra/eks infra/gke infra/aks; do
    if (cd "$d" && terraform init -backend=false -input=false -no-color >"${OUT}/err" 2>&1 \
          && terraform validate -no-color >"${OUT}/err" 2>&1); then
      ok "$d validates"
    else
      bad "$d does not validate: $(tail -5 "${OUT}/err")"
    fi
  done
else
  skip "terraform not installed"
fi

echo "== No hints in scanned files"
hints="$(grep -rnIiE 'planted|answer key|\bF[0-9]{2}\b|deprecat|legacy|end[- ]of[- ]life|\bEOL\b' \
           --exclude-dir=.terraform --exclude=.terraform.lock.hcl "${SCANNED_PATHS[@]}" 2>/dev/null)"
if [[ -n "$hints" ]]; then
  bad "hint words found in scanned paths:"; echo "$hints" | sed 's/^/        /'
else
  ok "no hint words in ${SCANNED_PATHS[*]}"
fi

echo "== Agent evidence vs .preflightignore"
if [[ -z "${PREFLIGHT_REPORT:-}" ]]; then
  skip "PREFLIGHT_REPORT not set"
elif ! have jq; then
  bad "jq is required to read ${PREFLIGHT_REPORT}"
else
  mapfile -t ignored < <(grep -vE '^\s*(#|$)' .preflightignore)
  leaked=""
  while IFS= read -r p; do
    p="${p#./}"
    for pat in "${ignored[@]}"; do
      if [[ "$pat" == */ && "$p" == "$pat"* ]] || [[ "$p" == $pat ]] || [[ "$p" == */$pat ]]; then
        leaked+="${p} (matches ${pat})"$'\n'
      fi
    done
  done < <(jq -r '.findings[]?.evidence[]?.path // empty' "${PREFLIGHT_REPORT}")
  if [[ -n "$leaked" ]]; then
    bad "agent cites ignored paths:"; printf '%s' "$leaked" | sed 's/^/        /'
  else
    ok "agent evidence only cites scanned paths"
  fi
fi

echo
echo "${pass} passed, ${fail} failed"
(( fail == 0 ))
