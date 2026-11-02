# Kubernetes upgrade readiness plan: 1.34 -> 1.38

Cluster `kube-pilot` (EKS, `prod-eks`) | scan `tOEl7qSFRESIWbt1yc5RQQ`
Zone: **AMBER** | Score: 77 now -> 92 after the fixes in this PR

Plan only. Nothing was upgraded, patched, scaled, restarted, or synced on the live cluster. All
cluster data below was read from the pipeline's read-only scan at `preflight/facts/`.

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.35 | FLAGGED | ASSUMED: confirm add-ons (aws-load-balancer-controller v2.8.1, coredns v1.12.4, ebs-csi-driver v1.67.2, vpc-cni v1.22.4, kube-proxy) are certified for 1.35 before this hop. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.36 | OK | No further removed-API findings for this hop in the scanned repo or live `deprecated_apis` facts. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | No further removed-API findings for this hop. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.38 | FLAGGED | Target. Re-verify the live `endpoints` client usage and the IRSA/Pod Identity coverage gap before promoting. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops (skew limit used: Kubernetes version-skew policy, kubelet up to 3 minor versions behind the API server, N-3, in effect for 1.28+)
| To | Notes |
|---|---|
| 1.35 | Node pool `general-...` kubelet (currently v1.34.12) stays within N-3 skew; no roll required yet. |
| 1.36 | Still within N-3 skew; no roll required yet. |
| 1.37 | Approaching the N-3 skew boundary; plan a node pool roll to stay compliant. |
| 1.38 | Roll node pool kubelet to at least 1.35 (N-3 of 1.38) to stay within the documented skew limit. |

## Platform checks (EKS) -- VERIFIED where stated, otherwise ASSUMED
- Node OS/runtime: VERIFIED from `nodes.json` -- Amazon Linux 2023.12.20261026, containerd 2.3.7. No action needed; AL2023 images are current.
- IRSA / EKS Pod Identity: ASSUMED -- not inferable from the facts collected (no ServiceAccount annotations in the scan). See coverage gap below.
- Add-on compatibility with 1.35-1.38: ASSUMED -- the scan only lists current add-on images (`addons.json`); no official compatibility matrix was fetched per instructions. Verify against AWS EKS add-on documentation before each hop.
- CRDs (`crds.json`): `targetgroupbindings.elbv2.k8s.aws` serves both `v1alpha1` and `v1beta1` while storing `v1beta1` -- VERIFIED from facts, not a core Kubernetes deprecation, no score impact; note for the AWS Load Balancer Controller owner.

## Findings and fixes (this PR)
1. **Removed API in use (15 pts, FIXED):** `flowcontrol.apiserver.k8s.io/v1beta3` (`FlowSchema`, `PriorityLevelConfiguration`) was removed in Kubernetes 1.32, at or before target 1.38.
   Fixed to `flowcontrol.apiserver.k8s.io/v1` in:
   - `platform/base/flowcontrol.yaml` (PriorityLevelConfiguration `demo-batch-priority`, FlowSchema `demo-batch-flowschema`)
   - `platform/flowcontrol/base/flowschema.yaml` (FlowSchema `batch-reporting`)
   - `platform/flowcontrol/base/prioritylevel.yaml` (PriorityLevelConfiguration `batch-reporting`)
   Validated: old apiVersion string no longer present in any of the three files.
2. **Deprecated-but-not-removed API, live (3 pts, NOT fixed):** the cluster's `deprecated_apis.json` shows clients still requesting the core `v1 endpoints` resource (successor: `discovery.k8s.io/v1 EndpointSlice`). No `apiVersion` field exists to patch -- this is caller behavior, most likely `platform/base/legacy-endpoints-cronjob.yaml`'s workload. Needs human review / app-owner migration, not a manifest fix.
3. **Coverage gap (5 pts):** IRSA / EKS Pod Identity ServiceAccount annotations were not collected by the read-only scan, so this EKS prerequisite is ASSUMED rather than VERIFIED.

## Owners to warn
No `CODEOWNERS` file was found in this repo, so per-namespace owners are **unknown** (not guessed). 7 namespaces were found referenced in manifests: see `preflight/generated/app-repo-map.json`. Route this PR through the on-call/platform team for review.

## Support status (endoflife.date, product `amazon-eks`)
| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.34 (current) | STANDARD | 2026-12-02 | 2027-12-02 |
| 1.38 (target) | UNKNOWN | - | - |

Urgency: **HIGH** -- current version 1.34 standard support ends 2026-12-02, within 90 days of today (2026-11-02). No official fee page was fetched, so monthly fees are UNKNOWN (not invented).

## Coverage gaps
- needs scan (read only): ServiceAccount IAM annotations (IRSA / EKS Pod Identity) for the EKS platform prerequisite check.
- endoflife.date has no published cycle yet for EKS 1.38 (target); target support status is UNKNOWN until AWS publishes it.

## Maps used
- Deprecation map: generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/ (DEPRECATION_MAP_PATH was not configured in this run), 37 entries across releases 1.16-1.32.
- App-repo map: generated from manifests + CODEOWNERS in this clone (APP_REPO_MAP_PATH was not configured in this run); 7 namespaces found, owners unknown (no CODEOWNERS file).
