# Kubernetes upgrade readiness plan

Cluster `kube-pilot` (EKS, prod-eks) | scan `S-aEoqX8R_u2iwFIycf-5g`
Current version: **1.34** | Target version: **1.34**

This is a readiness check at the current running version, not a multi-hop upgrade: the control
plane (`v1.34.11-eks-cfb47f5`, VERIFIED from `cluster_version.json`) already matches the target.

## Readiness scores
- Initial score: **67 / 100**
- Projected score (after the fixes in the accompanying PR are merged): **97 / 100**
- Zone: **AMBER** — merge the PR, then re-run Preflight to confirm GREEN.

## Control plane hops
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.34 | OK | Already at target version v1.34.11-eks-cfb47f5. No hop required. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops
Skew limit used: EKS documents node kubelet versions may trail the control plane by up to 2 minor
versions.

| To | Notes |
|---|---|
| 1.34 | Node pool `general-20261102163747225500000001` kubelet is `v1.34.12-eks` (VERIFIED from `nodes.json`), already at target minor and within the documented skew limit. No hop required. |

## Platform checks (EKS) — ASSUMED unless noted
- Node OS: Amazon Linux 2023.12.20261102, runtime `containerd://2.3.7+unknown`, arch arm64 (VERIFIED from `nodes.json`).
- IRSA / Pod Identity: not determinable from the collected facts (no IAM role annotations were scanned) — ASSUMED not evaluated, not a blocker.
- Add-on images (VERIFIED from `addons.json`): aws-load-balancer-controller v2.8.1, coredns v1.12.4-eksbuild.70, aws-ebs-csi-driver v1.67.2 (+ CSI sidecars), aws-node (VPC CNI) v1.22.4, aws-network-policy-agent v1.4.0 — no incompatibility evidence found against 1.34; ASSUMED compatible (release notes were not fetched, per instructions).
- CRDs (VERIFIED from `crds.json`): 9 CRDs found (networking.k8s.aws, vpcresources.k8s.aws, elbv2.k8s.aws groups); stored versions are all within served versions — no storage/serving mismatch.

## Risk narrative and findings
1. **VERIFIED (repo, fixed in PR)** — `flowcontrol.apiserver.k8s.io/v1beta3` (`FlowSchema`, `PriorityLevelConfiguration`) was removed in Kubernetes 1.32, at or before the target 1.34. Found in:
   - `platform/base/flowcontrol.yaml` (PriorityLevelConfiguration `demo-batch-priority`, FlowSchema `demo-batch-flowschema`)
   - `platform/flowcontrol/base/flowschema.yaml` (FlowSchema `batch-reporting`)
   - `platform/flowcontrol/base/prioritylevel.yaml` (PriorityLevelConfiguration `batch-reporting`)
   The deprecation guide names `flowcontrol.apiserver.k8s.io/v1` as the direct replacement. Patched and validated (old apiVersion string no longer present in any of the 3 files). **30 points fixed.**
2. **VERIFIED (live cluster + repo, not fixed)** — core `v1` `Endpoints` API still requested (`deprecated_apis.json` on the live cluster, and `platform/base/legacy-endpoints-cronjob.yaml` in the repo polls it every 5 minutes). Kubernetes deprecates this in favor of `discovery.k8s.io/v1` `EndpointSlice`, but the deprecation guide gives no fixed removal release and no 1:1 apiVersion swap — the CronJob script itself needs to change. Left as **needs human review**, 3 points outstanding.

No other removed or deprecated APIs were found in the scanned manifests, Helm chart (`charts/three-tier`), or Kustomize overlays — the application workloads already use current API versions (`apps/v1`, `v1`, `policy/v1`, `networking.k8s.io/v1`).

Terraform note (informational, not scored): `infra/aks/main.tf` pins `kubernetes_version = "1.32"` for the AKS environment. This is a different platform/environment from the scanned EKS cluster (`prod-eks`, target of this scan) and was not scored, but is worth a human look if an AKS upgrade is also planned.

## Owners to warn
No `CODEOWNERS` file exists in this repo, so the generated app-repo map could not resolve owners.
**Owners: unknown.** The affected manifests live under the `default` and `reporting` namespaces
(see `platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/*`, `platform/service-inventory/base/*`).

## Support status (endoflife.date, product `amazon-eks`)
| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.34 (current) | STANDARD | 2026-12-02 | 2027-12-02 |
| 1.34 (target) | STANDARD | 2026-12-02 | 2027-12-02 |

Fields used: `eol` → standard_end, `extendedSupport` → extended_end. Fees: UNKNOWN (no official page
with pricing was fetched). **Urgency: HIGH** — standard support for 1.34 ends 2026-12-02, within 90
days of today (2026-11-02).

## Coverage gaps
None. All six cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`,
`namespaces`) report `status: ok`. Both maps were generated successfully from official/repo sources
(the configured map paths `DEPRECATION_MAP_PATH` / `APP_REPO_MAP_PATH` did not exist on disk).

## Pull request
A PR with the 3-file fix above is raised from branch `preflight-fix/S-aEoqX8R` against `main`. Human
review and merge is required — nothing was applied to the live cluster.
