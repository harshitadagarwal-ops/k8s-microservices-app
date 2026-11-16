# Kubernetes upgrade plan: 1.32 -> 1.37

Cluster `kube-pilot` | EKS | prod-eks | scan `GSGucdcRRFuyp-gfNhR1-w`

**Zone: AMBER** — readiness score 55 (initial) -> 85 (projected after the fixes in the pull request). Plan only: nothing was upgraded.

## Control plane hops (every minor; EKS does not allow skipping minors)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | OK | Sequential EKS control plane minor upgrade | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.33.md |
| 1.34 | OK | Sequential EKS control plane minor upgrade | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md |
| 1.35 | OK | Sequential EKS control plane minor upgrade | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md |
| 1.36 | OK | Sequential EKS control plane minor upgrade | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.36.md |
| 1.37 | OK | Sequential EKS control plane minor upgrade | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.37.md |

EKS version/release details: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

## Node pool hops (skew limit used: 3 minor versions, per the Kubernetes version-skew policy — kubelet may be up to 3 minors older than kube-apiserver; VERIFIED from kubernetes.io)
Both node pools currently report kubelet v1.32.13, matching the control plane (skew 0).

| To | Notes |
|---|---|
| 1.34 | Must land before the control plane reaches 1.36, otherwise kubelet would be 4 minors behind kube-apiserver, exceeding the 3-minor skew limit. |
| 1.37 | Recommended final convergence to match the control plane exactly and remove the remaining skew; not strictly required by the skew policy alone (1.34 node / 1.37 control plane = 3-minor skew, still within limit). |

## Platform checks (EKS) — ASSUMED unless marked VERIFIED
- **VPC CNI / IRSA / Pod Identity**: ASSUMED compatible. `aws-node` DaemonSet image `v1.22.4-eksbuild.14` and `ebs-csi-controller` `v1.68.0` (from addons.json) are recent builds that support IRSA and EKS Pod Identity. No cloud API access was used, so the actual Pod Identity association was not confirmed.
- **Node AMI**: VERIFIED from nodes.json — both nodes run Amazon Linux 2023.12.20261112 with containerd 2.3.7, current and compatible with 1.32. Re-verify the AMI release notes at each future hop.
- **Add-on upgrade ordering**: ASSUMED. EKS managed add-ons (VPC CNI, kube-proxy, CoreDNS, EBS CSI driver) typically need a version published for the target control-plane minor before that hop. No incompatibility was found in addons.json, so no score deduction was applied — re-check the EKS add-on compatibility table immediately before each hop.
- **etcd / kubeadm (self-managed)**: not applicable — this is a managed EKS control plane.

## Risk narrative
- VERIFIED (from the live scan, deprecated_apis.json): no client is currently calling a removed/deprecated API against the live cluster.
- VERIFIED (from the repo scan against the official Kubernetes deprecation guide): 4 removed APIs are hard-coded in the `three-tier` Helm chart templates:
  - `extensions/v1beta1` Ingress (`admin-ingress.yaml`) — removed in 1.22, replacement `networking.k8s.io/v1` — **fixed in the PR**.
  - `autoscaling/v2beta1` HorizontalPodAutoscaler (`backend-hpa.yaml`) — removed in 1.25, replacement `autoscaling/v2` — **fixed in the PR**.
  - `batch/v1beta1` CronJob (`mysql-backup-cronjob.yaml`) — removed in 1.25, replacement `batch/v1` — **fixed in the PR**.
  - `policy/v1beta1` PodSecurityPolicy (`podsecuritypolicy.yaml`) — removed in 1.25, **no replacement named in the guide** — left unpatched, needs human migration to Pod Security Admission or a policy controller (OPA Gatekeeper, Kyverno).
- ASSUMED: after the automated `apiVersion` swap, the Ingress object should also be checked for the v1 `pathType`/`backend.service` schema, and the HPA object for the v2 `target.averageUtilization` schema — only the `apiVersion` line was changed, per the fix's limited scope.
- **Owners to warn**: unknown — no CODEOWNERS file (`CODEOWNERS`, `.github/CODEOWNERS`, `docs/CODEOWNERS`) was found in this repo, so ownership of the `three-tier` chart could not be derived.

## Support status
- **1.32 (current)**: EXTENDED support. Standard support ended 2026-03-23 (already passed — today is 2026-11-16); AWS extended support runs until 2027-03-23. **Urgency: CRITICAL** (standard support has already ended).
- **1.37 (target)**: STANDARD support, until 2027-12-01 (extended support until 2028-12-01).
- Fees: UNKNOWN — no official AWS page with EKS extended-support pricing was fetched in this run.
- Source: endoflife.date `amazon-eks` API; `eol` field used as standard_end, `extendedSupport` field used as extended_end.

## Coverage gaps
None — all cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`, `namespaces`) reported status `ok`, and both the deprecation map and the app-repo map were built successfully from official/repo sources.

## Score
- Deductions: 4 x removed-API findings (15 pts each, category capped at 45) = 45 pts deducted initially.
- Initial score: 100 - 45 = **55**.
- 3 of the 4 findings were fixed and validated in this run (PodSecurityPolicy was not, since it has no named replacement); remaining deduction = 15 pts.
- Projected score: 100 - 15 = **85**.
- Zone: initial 55 < 85 (not GREEN); projected 85 >= 60 -> **AMBER** (needs PR review and merge).
