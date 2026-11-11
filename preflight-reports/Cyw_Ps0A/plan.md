# Kubernetes upgrade plan: 1.32 -> 1.39

Cluster: kube-pilot | Platform: EKS | Env: prod-eks | Scan: Cyw_Ps0ARUKgRzEtaCOLTA

Readiness: **AMBER** — score 57 now, 87 after the fixes in the pull request (PR needs review and merge).

## Baseline check (ASSUMED risk, VERIFIED from facts)
- `CURRENT_VERSION` input is 1.32, but `cluster_version.json` (live, VERIFIED) shows the server is
  already `v1.34.12-eks-577a51e`, and `infra/eks/terraform.tfvars` (repo, VERIFIED) declares
  `cluster_version = "1.34"`. Nodes (`nodes.json`, VERIFIED) are at kubelet v1.34.12, in sync with
  the control plane — no live skew issue today. Confirm which baseline is correct before running this
  plan; hops below follow the configured CURRENT_VERSION (1.32) to TARGET_VERSION (1.39) as instructed.

## Control plane hops (every minor)
| To | Status | Notes |
|---|---|---|
| 1.33 | OK | Requires the flowcontrol.apiserver.k8s.io/v1 fix in this PR merged first (v1beta3 was removed in 1.32) |
| 1.34 | OK | No blockers found in the scanned facts or repo |
| 1.35 | OK | No blockers found in the scanned facts or repo |
| 1.36 | OK | No blockers found in the scanned facts or repo |
| 1.37 | FLAGGED | AL2023 node AMI documented valid for 1.32..1.36 only (infra/eks/eks.tf comment, VERIFIED repo data) — validate AMI support before this hop |
| 1.38 | FLAGGED | Same AMI caveat |
| 1.39 | FLAGGED | Same AMI caveat |

Release notes link for every EKS hop: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

## Node pool hops (skew limit used: 3 minor versions, the documented Kubernetes/EKS version-skew policy — kubelet may lag kube-apiserver by up to 3 minors)
| To | Notes |
|---|---|
| 1.35 | Catch up once control plane reaches 1.35 (keeps skew <= 3 minors) |
| 1.38 | Catch up once control plane reaches 1.38 |
| 1.39 | Final roll to match target |

## Platform checks (EKS)
- IRSA: `enable_irsa = true` in infra/eks/eks.tf (VERIFIED repo). Pod Identity not configured — ASSUMED not in use.
- Node image: Amazon Linux 2023 (nodes.json, VERIFIED). Repo comment states AL2023 is "valid on 1.32..1.36" (infra/eks/eks.tf, VERIFIED) — ASSUMED this still holds for 1.37-1.39; treat as a prerequisite to confirm.
- Add-ons (addons.json, VERIFIED): aws-load-balancer-controller v2.8.1, coredns v1.12.4, ebs-csi-driver v1.67.2, vpc-cni v1.22.4, kube-proxy v1.34.6. No compatibility matrix was fetched (out of allowed domains) — compatibility with 1.35-1.39 is ASSUMED unverified, recheck via each add-on's own release notes before each hop.

## Risk narrative
- **VERIFIED (repo + deprecation guide)**: `flowcontrol.apiserver.k8s.io/v1beta3` (FlowSchema, PriorityLevelConfiguration) was removed in Kubernetes 1.32 and is still referenced in `platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/flowschema.yaml` and `platform/flowcontrol/base/prioritylevel.yaml`. Fixed and validated in this PR (replaced with `v1`, the guide's documented replacement).
- **VERIFIED (live scan + repo)**: core/v1 `Endpoints` API is deprecated (flagged live in `deprecated_apis.json`) with no formal removal release yet, so the deprecation guide gives no replacement apiVersion. Used by `platform/base/legacy-endpoints-cronjob.yaml` (polls `kubectl get endpoints` every 5 minutes) and `platform/service-inventory/base/rbac.yaml`. Needs a human-authored migration to `discovery.k8s.io/v1` EndpointSlice — not patched automatically.
- **VERIFIED (endoflife.date)**: EKS 1.32 standard support ended 2026-03-23 (`eol` field); extended support runs to 2027-03-23 (`extendedSupport` field). Today is 2026-11-11, so standard support has already lapsed — urgency CRITICAL. Target 1.39 is not yet a published EKS cycle in endoflife.date — support status UNKNOWN, recheck closer to the upgrade.
- **ASSUMED**: add-on and CRD compatibility across hops 1.33-1.39 (no compatibility matrix fetched).

## Owners to warn (app-repo map, derived — no CODEOWNERS file found in the repo, so owners are unknown)
| Namespace | Files | Owners |
|---|---|---|
| argocd | argocd/*/apps.yaml, gitops/dev-aks/apps.yaml | unknown |
| demo | argocd/*/apps.yaml, gitops/dev-aks/apps.yaml | unknown |
| default | argocd/*/apps.yaml, platform/base/flowcontrol.yaml | unknown |
| cert-manager | argocd/*/apps.yaml, gitops/dev-aks/apps.yaml | unknown |
| ingress-nginx | argocd/*/apps.yaml, gitops/dev-aks/apps.yaml | unknown |
| reporting | gitops/onprem/apps.yaml, platform/flowcontrol/base/flowschema.yaml, platform/service-inventory/base/* | unknown |
| harness-preflight | harness/PreflightAgentPipelineKubePilot_Harshita.yaml, manifests-eks/preflight-readonly-rbac.yaml | unknown |

## Score
- Deductions: removed API FlowSchema v1beta3 (-15, fixed), removed API PriorityLevelConfiguration
  v1beta3 (-15, fixed), deprecated Endpoints API in use (-3, unfixed), AL2023 AMI range prerequisite
  (-5, unfixed), CURRENT_VERSION/live-version mismatch prerequisite (-5, unfixed).
- initial = 57, projected after this PR's fixes = 87. Zone AMBER: merge the PR, then re-run a scan
  to confirm, and resolve the remaining unfixed items (Endpoints migration, AMI validation,
  baseline confirmation) before starting the hops.

## Coverage gaps
None — all cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`,
`namespaces`) read with status `ok`; both maps were generated successfully since the configured
paths (`/harness/preflight-config/*.json`) did not exist.

Plan only: nothing was upgraded, no cluster writes were made.
