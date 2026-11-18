# Kubernetes upgrade plan: 1.33 -> 1.34

Cluster `kube-pilot` | EKS | prod-eks | scan `0O-0VGGWRaqxS0yUC7I7lw`

**Readiness: AMBER — 47 now, 83 projected after the fixes in the pull request (needs PR review and merge).**

This is a plan only. Nothing in the live cluster was changed, and no cluster write/exec/delete
command was ever issued by this run.

## Control plane track (every minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.34 | FLAGGED | Single minor hop from the current server version v1.33.13-eks. Flagged because `charts/three-tier` (the chart used by `prod-eks` in both `gitops/prod-eks/apps.yaml` and `argocd/prod-eks/apps.yaml`) still contains a `PodSecurityPolicy` manifest with no replacement API, and because namespace owners for that chart could not be determined (no CODEOWNERS file in this repo). | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool track (may lag within the documented skew limit)

Skew limit used: the Kubernetes version skew policy (effective since control plane v1.28) allows a
kubelet to run up to **3 minor versions (n-3)** behind the kube-apiserver. VERIFIED from
`nodes.json`: all 3 nodes (pools `general-20261118160028208800000001` and
`delegate-2026111810572210660000000a`) are at kubelet `v1.33.13-eks`, matching the current control
plane.

| To | Notes |
|---|---|
| 1.34 | Not mandatory immediately (nodes at 1.33 stay within the n-3 skew once the control plane is 1.34). Recommended to roll node pools to 1.34 kubelet/AMI shortly after the control plane hop is verified healthy, to avoid carrying skew into a future hop. |

## Risk narrative

- **VERIFIED (live scan, `deprecated_apis.json`):** the API server logged a client request for the
  deprecated `v1` `Endpoints` resource. This API is deprecated in favor of `discovery.k8s.io`
  `EndpointSlice` but is still served; no release has scheduled its removal, so this is informational
  only.
- **VERIFIED (repo scan):** `charts/three-tier`, the Helm chart deployed by the `prod-eks` GitOps apps,
  contained 5 manifests using Kubernetes API versions removed at or before 1.25:
  - `admin-ingress.yaml` — `extensions/v1beta1` Ingress (removed 1.22) — **fixed in this PR** →
    `networking.k8s.io/v1`
  - `backend-hpa.yaml` — `autoscaling/v2beta1` HorizontalPodAutoscaler (removed 1.25) — **fixed in
    this PR** → `autoscaling/v2`
  - `backend-pdb.yaml` — `policy/v1beta1` PodDisruptionBudget (removed 1.25) — **fixed in this PR** →
    `policy/v1`
  - `mysql-backup-cronjob.yaml` — `batch/v1beta1` CronJob (removed 1.25) — **fixed in this PR** →
    `batch/v1`
  - `podsecuritypolicy.yaml` — `policy/v1beta1` PodSecurityPolicy (removed 1.25) — **not patched**,
    the Kubernetes deprecation guide names no replacement API; needs a human decision (for example
    Pod Security Admission labels or an admission-controller policy).
  None of these removed manifests currently resolve live (the cluster already runs 1.33, which
  rejects these API versions), so this is a repo-only risk that should be cleaned up before anyone
  tries to re-apply this chart on a server at or beyond the removal version.
- **VERIFIED (`addons.json`):** kube-system add-ons (aws-load-balancer-controller v2.8.1, CoreDNS
  v1.12.4-eksbuild.82, EBS CSI driver v1.68.0, VPC CNI/aws-node v1.22.4-eksbuild.14) are present with
  recent image tags. No incompatibility with 1.34 could be confirmed or ruled out without fetching the
  EKS add-on compatibility matrix, which this run does not do — treat as **ASSUMED OK**, re-verify
  against AWS's published add-on version matrix before the hop.
- **ASSUMED:** EKS platform prerequisites (IRSA role trust / Pod Identity associations, control-plane
  upgrade insights) could not be checked — the collected cluster facts do not include IAM or
  EKS-control-plane-API data. See coverage gaps.

## Owners to warn

The app-repo map was generated from the cloned repo (no `DEPRECATION_MAP_PATH` /
`APP_REPO_MAP_PATH` file was present, so both maps were built in this run). This repo has no
`CODEOWNERS` file, so owners for the affected namespaces/chart are **unknown** — do not guess; route
the pull request to whoever maintains `charts/three-tier` and the `prod-eks` GitOps apps.

## Support status

| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.33 (current) | EXTENDED | 2026-07-29 | 2027-07-29 |
| 1.34 (target) | STANDARD | 2026-12-02 | 2027-12-02 |

Urgency: **CRITICAL** — standard support for the current version (1.33) ended 2026-07-29 (today is
2026-11-18); the cluster is now in EKS extended support. Fees: UNKNOWN (no official pricing page was
fetched in this run).

## Coverage gaps

- needs scan (read only): EKS platform prerequisites (IRSA/Pod Identity associations, control plane
  upgrade insights) were not collected by the cluster facts scan available to this run.

## Release links

- Kubernetes CHANGELOG for 1.34:
  https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md
- EKS Kubernetes versions page:
  https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
