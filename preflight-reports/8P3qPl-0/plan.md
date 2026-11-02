# Kubernetes upgrade plan: 1.34 -> 1.38

Cluster `kube-pilot` (EKS, prod-eks), scan `8P3qPl-0QUyC4D1D7GigVw`. Plan only: nothing was upgraded.

## Readiness

- initial score: **32** (AMBER would need 60+ projected, GREEN needs 85+ initial)
- projected score after this PR's fixes: **77** -> zone **AMBER** (needs PR review and merge)

## Control plane hops (every minor)

| To | Status | Notes |
|---|---|---|
| 1.35 | FLAGGED | `charts/three-tier/Chart.yaml` `kubeVersion: ">=1.28.0-0 <1.34.0-0"` already excludes the current 1.34 control plane; widen it before any hop proceeds (VERIFIED from repo, not patched here). The `flowcontrol.apiserver.k8s.io/v1beta3` removal (removed in 1.32, VERIFIED from the kubernetes.io deprecation guide) is fixed in the accompanying PR. |
| 1.36 | OK | No additional repo-detected blockers beyond the carried-over Chart.yaml constraint. |
| 1.37 | OK | Node pool may still sit at 1.34 here (skew of 3, at the documented kubelet n-3 limit). |
| 1.38 | FLAGGED | Node pool must be rolled to at least 1.35 at or before this hop to stay within the kubelet skew policy. |

Release notes: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html (EKS version page, covers all hops above).

## Node pool hops

Skew limit used: **n-3** (documented Kubernetes kubelet policy: kubelet must be no more than 3 minor
versions behind kube-apiserver). Live nodes are at kubelet v1.34.12 (VERIFIED from `nodes.json`).

| To | Notes |
|---|---|
| 1.38 | Node pool may remain at 1.34 through the control-plane 1.35-1.37 hops under the n-3 skew policy. Roll it to 1.38 at or before the final control-plane hop so skew never exceeds 3. |

## Platform checks (EKS)

- Node AMI: `AL2023_x86_64_STANDARD` (VERIFIED from `infra/eks/eks.tf` and `nodes.json` OS image) -
  current AL2023 family, no AMI migration needed for this hop range.
- IRSA: `enable_irsa = true` plus an EBS CSI IRSA role is configured (VERIFIED from `infra/eks/eks.tf`).
  Pod Identity is not configured; this is a style choice, not a blocker. ASSUMED no other workload
  depends on Pod Identity specifically (not visible in the scanned facts).
- containerd runtime: `containerd://2.3.7` on both nodes (VERIFIED from `nodes.json`) - current for
  this hop range.
- Terraform `infra/eks/variables.tf` `cluster_version` default is `1.32`, but the live control plane is
  1.34 (VERIFIED from `cluster_version.json`) - IaC has drifted from the running cluster. ASSUMED this
  is because `-var` overrides are used at apply time; confirm and fix the default before any hop apply
  so a plan does not attempt to move the cluster backwards.
- AWS Load Balancer Controller (`v2.8.1`) and VPC CNI (`v1.22.4`) CRD/compatibility with Kubernetes
  1.38 could not be verified: vendor CRDs are outside the kubernetes.io deprecation guide used to build
  the deprecation map, and fetching AWS release notes is out of scope for this run. Listed as a
  coverage gap.

## Risk narrative

- `flowcontrol.apiserver.k8s.io/v1beta3` (PriorityLevelConfiguration/FlowSchema) is used in
  `platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/flowschema.yaml` and
  `platform/flowcontrol/base/prioritylevel.yaml`. VERIFIED removed in Kubernetes 1.32 (current control
  plane is already 1.34), so these manifests are already invalid against the running API server.
  Replacement `flowcontrol.apiserver.k8s.io/v1` applied in the accompanying PR (mechanical field-for-field
  swap, VERIFIED against the deprecation guide).
- `charts/three-tier/Chart.yaml` `kubeVersion` upper bound `<1.34.0-0` already excludes the current
  control plane and every hop to 1.38 (VERIFIED). Not a deprecation-map apiVersion swap, so left for
  human review rather than patched.
- `platform/base/legacy-endpoints-cronjob.yaml` polls the core `v1` Endpoints API every 5 minutes.
  VERIFIED soft-deprecated by the live `deprecated_apis.json` fact (client requests seen, no scheduled
  removal release). No replacement apiVersion exists in the deprecation map for this resource, so it
  was left for the owning team to move to EndpointSlices.
- Owners to warn: unknown - no CODEOWNERS file was found in the cloned repo (checked `CODEOWNERS`,
  `.github/CODEOWNERS`, `docs/CODEOWNERS`). Namespaces found in manifests: default, demo,
  harness-delegate-ng, harness-preflight, kube-node-lease, kube-public, kube-system.

## Support status

- Current (1.34): STANDARD, standard support ends 2026-12-02, extended support ends 2027-12-02
  (source: endoflife.date amazon-eks API, fields `eol` and `extendedSupport`). Urgency: **HIGH**
  (standard support ends within 90 days of the current date, 2026-11-02).
- Target (1.38): UNKNOWN - the endoflife.date amazon-eks dataset's newest listed cycle is 1.37, so no
  support dates or fees are published yet for 1.38. Fees overall: UNKNOWN (no official page fetched
  states a figure).

## Coverage gaps

- needs scan (read only): AWS Load Balancer Controller / VPC CNI CRD compatibility with Kubernetes
  1.38 (vendor CRDs are not covered by the kubernetes.io deprecation guide used to build the
  deprecation map).
- endoflife.date amazon-eks dataset does not yet list a 1.38 cycle, so target-version support
  dates/fees are UNKNOWN.

## Fix PR

Repo `k8s-microservices-app` (github): 3 files patched (`flowcontrol.apiserver.k8s.io/v1beta3` ->
`v1`), validated, and submitted as a PR for review. See `preflight/prs/k8s-microservices-app/` for the
exact PR title and body used.
