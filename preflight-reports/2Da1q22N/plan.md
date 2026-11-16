# Kubernetes upgrade plan: 1.32 -> 1.33

Cluster `kube-pilot` | EKS | prod-eks | scan `2Da1q22NQ5yD4s43zYgNAA`

Readiness: **AMBER** - initial score 50/100, projected 95/100 after the fixes in the accompanying
pull request are merged. Plan only: nothing in this cluster was upgraded.

## Control plane hops (every minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | FLAGGED | Single hop (1.32 -> 1.33). Flagged because the PodSecurityPolicy template is unfixed and already incompatible with the current 1.32 API server. The other three removed-API findings are fixed in the PR. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops

Node pool `general-...` kubelet is currently v1.32.13-eks, matching the control plane (VERIFIED from
`nodes.json`). Kubernetes kubelet-to-kube-apiserver version-skew policy allows the kubelet to lag the
control plane by up to 3 minor versions (ASSUMED - general policy, not refetched this run). A single
combined hop of both tracks to 1.33 is within that skew limit.

| To | Notes |
|---|---|
| 1.33 | Node pools may move together with the control plane in this single hop; within the documented skew limit either way. |

## Platform checks (EKS)

- Node OS: Amazon Linux 2023.12.20261112, containerd 2.3.7 (VERIFIED from `nodes.json`). No cgroup or
  OS blocker evident.
- Add-ons observed in `kube-system` (VERIFIED from `addons.json`): aws-load-balancer-controller
  v2.8.1, coredns v1.11.4-eksbuild, aws-ebs-csi-driver v1.68.0 (+ csi sidecars), aws-node (VPC CNI)
  v1.22.4-eksbuild. No incompatibility with 1.33 is indicated by the scan; versions look current
  (ASSUMED compatible - release notes were not fetched for each add-on per the no-fetch rule).
- IRSA / EKS Pod Identity: service account IAM role annotations were not part of the cluster scan, so
  this EKS prerequisite could not be verified. Recorded as a coverage gap below.
- CRDs (VERIFIED from `crds.json`): all 9 CRDs are AWS VPC CNI / ELB related
  (`*.k8s.aws`, `*.vpcresources.k8s.aws`, `crd.k8s.amazonaws.com`), stored and served versions match,
  no cross-version drift detected.

## Risk narrative

- **VERIFIED (live + repo)**: no deprecated API usage was reported by the live cluster scan
  (`deprecated_apis.json` is empty), i.e. no client is currently requesting a soon-to-be-removed API
  version against the live API server.
- **VERIFIED (repo)**: the cloned repo `k8s-microservices-app` (chart `charts/three-tier`) contains
  four manifests using APIs already removed from the Kubernetes API as of 1.25/1.22, all at or before
  the 1.33 target:
  - `extensions/v1beta1` Ingress (`admin-ingress.yaml`, removed 1.22) - **fixed** in the PR
    (`networking.k8s.io/v1`).
  - `autoscaling/v2beta1` HorizontalPodAutoscaler (`backend-hpa.yaml`, removed 1.25) - **fixed** in
    the PR (`autoscaling/v2`, metrics block updated to the v2 shape already used by
    `frontend-hpa.yaml`).
  - `batch/v1beta1` CronJob (`mysql-backup-cronjob.yaml`, removed 1.25) - **fixed** in the PR
    (`batch/v1`).
  - `policy/v1beta1` PodSecurityPolicy (`podsecuritypolicy.yaml`, removed 1.25, **no replacement API**
    per the deprecation guide) - **not patched**, needs human review. It is enabled
    (`podSecurityPolicy.enabled: true`) in `values-prod-eks.yaml`, the values file for this cluster's
    environment. Migrating to Pod Security Admission or an external policy controller (OPA/Gatekeeper,
    Kyverno) is a manual decision outside an automated fix.
- These removed-API manifests would already fail to apply against the *current* 1.32 API server, so
  they are pre-existing issues independent of the 1.33 hop, not new blockers introduced by it.

## Owners to warn

No `CODEOWNERS` file was found in the repo (checked `CODEOWNERS`, `.github/CODEOWNERS`,
`docs/CODEOWNERS`). Owners for the affected namespaces are **unknown** - do not guess; route the PR to
whoever owns `charts/three-tier` by other means.

Namespaces referenced across the repo's manifests (from the generated app-repo map): 7 namespaces
found across Argo CD app-of-apps and chart templates, including the `prod-eks`, `staging-gke`,
`dev-aks` and `onprem` Argo CD overlays.

## Support status

| Version | Status | Standard support ends | Extended support ends |
|---|---|---|---|
| 1.32 (current) | EXTENDED | 2026-03-23 | 2027-03-23 |
| 1.33 (target) | EXTENDED | 2026-07-29 | 2027-07-29 |

Source: `https://endoflife.date/api/amazon-eks.json`, fields `eol` (standard support end) and
`extendedSupport` (extended support end). As of today (2026-11-16), **both** the current and the
target version are already past standard support and are in paid extended support. Monthly fees:
UNKNOWN (no official pricing page was fetched this run).

**Urgency: CRITICAL** - standard support for the current version has already ended.

## Coverage gaps

- needs scan (read only): service account IAM annotations (IRSA / EKS Pod Identity) for EKS
  prerequisite check.

## Score

- Initial: 50/100 (deductions: 45 points for 4 distinct removed-API findings, capped at the 45-point
  removed-API category ceiling; 5 points for the one coverage gap).
- Projected: 95/100 after the 3 validated, merged fixes (Ingress, HPA, CronJob). The unfixed
  PodSecurityPolicy finding and the coverage gap remain.
- Zone: AMBER (initial < 85, projected >= 60) - the pull request needs review and merge.
