# Kubernetes upgrade readiness plan: 1.34 to 1.38

Cluster `kube-pilot` (EKS, prod-eks), scan `Kb_bmd79QNufuvakg35m2Q`. Plan only — nothing in the live cluster was changed.

## Readiness

- Zone: **AMBER** (needs the accompanying PR reviewed and merged)
- Score: 82 now, 97 after the fixes in the pull request
- Deductions: removed API `flowcontrol.apiserver.k8s.io/v1beta3` in repo (15 pts, **fixed**); live client requests for core v1 `endpoints` with no official removal/replacement mapped (3 pts, **not fixed** — needs human review)

## Control plane hops (every minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.35 | OK | No removed APIs identified between 1.34 and 1.35 for this repo. The repo's only removed-API finding (`flowcontrol.apiserver.k8s.io/v1beta3`, removed in 1.32 — already behind the current 1.34 server) is fixed in the accompanying PR and must merge before any further GitOps sync, independent of hop timing. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.36 | OK | No removed APIs identified between 1.35 and 1.36 for this repo. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | No removed APIs identified between 1.36 and 1.37 for this repo. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.38 | OK | No removed APIs identified between 1.37 and 1.38 for this repo. Review the live `endpoints` finding (top blocker) independently of this hop plan. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops (may lag within the documented skew limit)

Skew limit used: kubelet may be up to 3 minor versions older than kube-apiserver (Kubernetes version skew policy for kubelet >= 1.28, as documented by EKS).

| To | Notes |
|---|---|
| 1.35 | Node pools may remain on 1.34 through the control-plane hops to 1.35, 1.36 and 1.37. Roll node pools to at least 1.35 before or during the 1.37 control-plane hop so they stay within N-3 once the control plane reaches 1.38. |
| 1.38 | Final node pool roll to match the target control-plane version 1.38. |

## Risk narrative

- VERIFIED (live scan): server is `v1.34.11-eks-cfb47f5`; both nodes run kubelet `v1.34.12-eks-577a51e`, containerd `2.3.7`, Amazon Linux 2023 — within skew of the control plane today.
- VERIFIED (live scan): `deprecated_apis.json` shows clients still requesting core `v1 endpoints` (group `""`). This is not covered by the official Kubernetes API deprecation guide (no removal release, no replacement listed), so it is reported as a deprecated-but-not-removed finding rather than a removed API. ASSUMED: the `FlowSchema` in `platform/base/flowcontrol.yaml` that authorizes a service account to `get`/`list` `endpoints` may be the source of this request pattern — worth checking first.
- VERIFIED (repo scan): `flowcontrol.apiserver.k8s.io/v1beta3` (`PriorityLevelConfiguration`, `FlowSchema`) appears in `platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/flowschema.yaml` and `platform/flowcontrol/base/prioritylevel.yaml`. This API was removed in Kubernetes 1.32 — already behind the current server version 1.34 — so these manifests would already fail to apply via Argo CD sync today, independent of any further upgrade. Fixed in the accompanying PR by bumping to `flowcontrol.apiserver.k8s.io/v1`.
- ASSUMED: add-on versions in `kube-system` (aws-load-balancer-controller v2.8.1, coredns v1.12.4-eksbuild.66, ebs-csi-controller v1.67.2, VPC CNI v1.22.4) are recent enough to be compatible through 1.38, but this was not confirmed against release notes (not fetched per instructions) — reverify compatibility before each hop.
- ASSUMED: EKS IRSA/Pod Identity and cgroup v2 prerequisites are met (Amazon Linux 2023 nodes default to cgroup v2, containerd runtime present) — not confirmed via cloud API (out of scope for this read-only agent).
- `infra/aks/main.tf` pins `kubernetes_version = "1.32"` for a separate dev-aks cluster — unrelated to this prod-eks upgrade target, noted for awareness only.

## Owners to warn

No `CODEOWNERS` file was found in the repo, so owners are **unknown** for the 7 namespaces discovered in manifests (`default`, `demo`, `harness-delegate-ng`, `harness-preflight`, `kube-node-lease`, `kube-public`, `kube-system`, plus app namespaces referenced in Helm values). Do not guess owners; add a CODEOWNERS file to enable this in future runs.

## Support status

- Current (1.34): STANDARD, standard support ends 2026-12-02 (30 days from today), extended support ends 2027-12-02. Urgency: **HIGH** (within 90 days of standard end).
- Target (1.38): UNKNOWN — not present in the endoflife.date `amazon-eks` cycle list (latest listed cycle is 1.37) as of this scan.
- Fees: UNKNOWN (no official page fetched stating fees).

## Coverage gaps

- Support status for target version 1.38 is not available from endoflife.date (amazon-eks cycles listed only up to 1.37).
