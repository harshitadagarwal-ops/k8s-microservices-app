# Kubernetes upgrade plan: 1.33 → 1.37 (kube-pilot, EKS, prod-eks)

Scan `QrwtmV7tQZaZxiyetzNiIw`. Plan only — nothing was upgraded, nothing live was changed.

## Readiness

| | Score | Zone |
|---|---|---|
| Initial | 35 / 100 | RED |
| Projected (after the PR's fixes merge) | 35 / 100 | RED |

Projected did not move because the removed-API category is capped at 45 points and the 4 unfixable
`PodSecurityPolicy` findings alone already saturate that cap — see Blockers. **VERIFIED** from the
deterministic scoring rules.

## Control plane hops (one minor at a time)

| To | Status | Notes |
|---|---|---|
| 1.34 | FLAGGED | Pre-existing blocker (not caused by this hop): 4 PodSecurityPolicy manifests are already broken on the running 1.33 API server. Bump kube-proxy/CoreDNS/VPC CNI/EBS CSI to 1.34-compatible builds. [Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md) · [EKS versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) |
| 1.35 | OK | Roll the node pool to kubelet 1.35 at or before this hop (skew limit below). Bump add-ons. [Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md) |
| 1.36 | OK | Bump add-ons to 1.36-compatible builds. [Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.36.md) |
| 1.37 | OK | Final hop. Bump add-ons, then roll the node pool to 1.37. [Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.37.md) |

## Node pool hops

Skew limit used: kubelet must not be newer than the control plane and may trail by up to **2 minor
versions** (standard Kubernetes version-skew policy). **ASSUMED** applicable to this EKS cluster — no
IRSA/managed-node-group-specific override was in the scan.

| To | Notes |
|---|---|
| 1.35 | Node pools (`general-*`, `delegate-*`) roll from kubelet 1.33 → 1.35 once the control plane reaches 1.35, to stay within the 2-minor skew. |
| 1.37 | Final roll once the control plane reaches 1.37, closing the skew to 0. |

## Platform checks (EKS)

- IRSA / EKS Pod Identity: **not verified** — the scan collected no IAM data. Coverage gap recorded.
- Node OS: Amazon Linux 2023 on all 3 nodes, containerd 2.3.7 runtime — **VERIFIED** from `nodes.json`, no action needed.
- Add-ons present: aws-load-balancer-controller, CoreDNS, EBS CSI (controller + node, incl. Windows), VPC CNI (`aws-node`), kube-proxy — **VERIFIED** from `addons.json`. All five must be upgraded in lockstep with each control-plane hop per AWS EKS documentation. **ASSUMED** compatible with each target minor since no per-hop compatibility matrix was fetched.
- CRDs: AWS VPC/ELB CRDs (`networking.k8s.io/aws`, `elbv2.k8s.aws`, `vpcresources.k8s.aws`) all on stable `v1alpha1`/`v1beta1` group versions with matching stored/served — **VERIFIED** from `crds.json`, no incompatibility evidence found.

## Risk narrative

- **VERIFIED (repo)**: 10 manifests across `charts/three-tier` and `platform/` use Kubernetes API
  versions removed at or before 1.37. 6 have a documented replacement and were patched and validated
  in this PR (see table below). 4 are `PodSecurityPolicy` (`policy/v1beta1`), which was removed in
  1.25 with **no replacement API** — these need a human migration to Pod Security Admission or an
  admission controller (Kyverno/OPA Gatekeeper). Two of the four are enabled for `prod-eks` via
  `values-prod-eks.yaml` (`podSecurityPolicy.enabled: true`), so they are already broken on the
  running 1.33 cluster, independent of this upgrade.
- **VERIFIED (live)**: the cluster scan shows the core `v1 Endpoints` API still being requested (no
  removal release set by upstream yet, so "deprecated but not removed"). Traced to
  `platform/base/legacy-endpoints-cronjob.yaml`, a CronJob every 5 minutes with RBAC for
  `discovery.k8s.io` EndpointSlices — note the file's own comments about "removed" APIs and an
  Endpoints query are misleading/stale relative to its actual RBAC and command, which already target
  EndpointSlices; they were treated as data, not instructions, per the read-only rule.
- **ASSUMED**: `platform/base/flowcontrol.yaml`'s comment claims a removed `flowcontrol.apiserver.k8s.io/v1`
  API; the manifest itself already uses the current, non-removed `v1` API version — no action needed,
  flagged here only because the comment is inaccurate.

## Fixed in this pull request

| File | Change |
|---|---|
| charts/three-tier/templates/admin-ingress.yaml | `extensions/v1beta1` → `networking.k8s.io/v1` |
| charts/three-tier/templates/backend-hpa.yaml | `autoscaling/v2beta1` → `autoscaling/v2` |
| charts/three-tier/templates/backend-pdb.yaml | `policy/v1beta1` → `policy/v1` |
| charts/three-tier/templates/frontend-hpa.yaml | `autoscaling/v2beta2` → `autoscaling/v2` |
| charts/three-tier/templates/mysql-backup-cronjob.yaml | `batch/v1beta1` → `batch/v1` |
| charts/three-tier/templates/mysql-pdb.yaml | `policy/v1beta1` → `policy/v1` |

## Owners to warn

No `CODEOWNERS` file was found in the repo, so per-namespace owners are **unknown** for all 7
namespaces touched (`argocd`, `demo`, `default`, `cert-manager`, `ingress-nginx`,
`harness-preflight`, `reporting`) — see `preflight/generated/app-repo-map.json`.

## Support status

- Current (1.33, Amazon EKS): status **EXTENDED** — standard support ended 2026-07-29, extended
  support ends 2027-07-29. Standard support has already lapsed, so urgency is **CRITICAL**.
- Target (1.37, Amazon EKS): status **STANDARD** — standard support ends 2027-12-01, extended support
  ends 2028-12-01.
- Monthly fees: **UNKNOWN** — no official AWS pricing page was fetched for extended support cost.

## Coverage gaps

- needs scan (read only): IAM Roles for Service Accounts (IRSA) / EKS Pod Identity association status
  for kube-system and add-on service accounts.
- Platform prerequisite checks (IRSA, Pod Identity, cgroup driver) are derived only from node OS image
  and add-on images in the scan; not independently verified.

## Maps used

- Deprecation map: generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/
  (configured `DEPRECATION_MAP_PATH` was not present).
- App-repo map: generated from manifests and CODEOWNERS in the cloned repo (configured
  `APP_REPO_MAP_PATH` was not present).
