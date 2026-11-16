# Kubernetes upgrade plan: 1.32 -> 1.34 (kubepilot, EKS, prod-eks)

Scan RSJAU2S5QUe5z5CXwyD7cQ. Readiness score: **52 now -> 82 projected** after the fixes in the pull
request. Zone: **AMBER** (needs PR review and merge).

## Control plane hops (every minor)
1. **1.32 -> 1.33** — OK. [EKS version docs](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).
   No removed-API finding targets this hop specifically. Re-run Preflight after this hop.
2. **1.33 -> 1.34** — FLAGGED (target). [EKS version docs](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).
   The unfixed `PodSecurityPolicy` template must be resolved by a human before/at this hop if any
   environment sets `podSecurityPolicy.enabled: true` (prod-eks does, see `values-prod-eks.yaml`).

## Node pool track
Node pool `general-20261115161132087800000008` is at kubelet v1.32.13, in sync with the control
plane (VERIFIED from `nodes.json`). Skew limit used: the Kubernetes version-skew policy allows the
kubelet to run up to 3 minor versions behind kube-apiserver (n-3,
https://kubernetes.io/releases/version-skew-policy/). So the node pool does not need to track every
control-plane minor and can roll directly **1.32 -> 1.34** in one hop once the control plane reaches
1.34.

## Platform checks (EKS) — ASSUMED unless noted
- IRSA: `serviceAccount.annotations["eks.amazonaws.com/role-arn"]` is set in `values-prod-eks.yaml`
  (VERIFIED from repo) — classic IRSA, still supported at 1.34. Pod Identity adoption not assessed
  (no cloud API access).
- Node OS: Amazon Linux 2023, containerd runtime (VERIFIED from `nodes.json`) — compatible track for
  1.34.
- Add-on images (aws-load-balancer-controller v2.8.1, VPC CNI v1.22.4, EBS CSI v1.68.0, CoreDNS
  v1.11.4, kube-proxy matching control plane) were read from `addons.json` but their minimum-required
  versions for 1.34 were NOT verified (release notes fetch is out of scope) — ASSUMED compatible
  pending a human check against the AWS EKS add-on compatibility table.

## Risk narrative and findings
- **extensions/v1beta1 Ingress** removed in 1.22, found in `charts/three-tier/templates/admin-ingress.yaml`
  (VERIFIED, repo scan). **Fixed and validated** in the pull request: apiVersion ->
  `networking.k8s.io/v1`, backend restructured to `service.name`/`service.port.number`, `pathType: Prefix` added.
- **autoscaling/v2beta1 HorizontalPodAutoscaler** removed in 1.26, found in
  `charts/three-tier/templates/backend-hpa.yaml` (VERIFIED). **Fixed and validated**: apiVersion ->
  `autoscaling/v2`, metric restructured to `target.type: Utilization` / `target.averageUtilization`
  (matches the existing pattern already used in `frontend-hpa.yaml`).
- **batch/v1beta1 CronJob** removed in 1.25, found in `charts/three-tier/templates/mysql-backup-cronjob.yaml`
  (VERIFIED). **Fixed and validated**: apiVersion -> `batch/v1` (spec shape unchanged between the two versions).
- **policy/v1beta1 PodSecurityPolicy** removed in 1.25 with **no replacement API**
  (VERIFIED from the Kubernetes deprecation guide), found in
  `charts/three-tier/templates/podsecuritypolicy.yaml`, enabled for prod-eks. **Not patched** —
  needs human migration to Pod Security Admission or an OPA/Gatekeeper/Kyverno policy.
- **Deprecated core/v1 Endpoints API** polled every 5 minutes by
  `platform/base/legacy-endpoints-cronjob.yaml` (VERIFIED from repo; the file's own comment notes
  this is deprecated ahead of `discovery.k8s.io/v1` EndpointSlices — ASSUMED accurate, not independently
  confirmed against the live `deprecated_apis.json` scan, which returned no entries). Not patched:
  this requires a client code change, not an apiVersion swap.
- Live cluster scan (`deprecated_apis.json`) found **no** API server requests for removed/deprecated
  APIs at the time of the scan (VERIFIED, status ok, empty result) — all removed-API findings above
  come from the repo scan of manifests that may not currently be deployed to every environment.
- CRDs (`crds.json`) show no stored-but-unserved version mismatches (VERIFIED) — no CRD migration
  blocker found.

## Owners to warn
No `CODEOWNERS` file was found in the cloned repo (checked `CODEOWNERS`, `.github/CODEOWNERS`,
`docs/CODEOWNERS`) — owners are **unknown** for the affected namespaces (`default`, and the
namespaces implied by the Helm chart). Do not guess; route the pull request to whoever owns
`charts/three-tier` and `platform/base` manually.

## Support status
- Current (1.32): status **EXTENDED** — standard support ended 2026-03-23, extended support ends
  2027-03-23 (endoflife.date API, `eol`/`extendedSupport` fields). Standard support has already
  lapsed.
- Target (1.34): status **STANDARD** — standard support ends 2026-12-02, extended support ends
  2027-12-02 (same source/fields). The standard window closes in under a month from today
  (2026-11-16).
- Fees: UNKNOWN (no official AWS pricing page was fetched; do not infer a monthly figure).
- Urgency: **CRITICAL** — the running version's standard support window has already ended.

## Coverage gaps
None. All six cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`,
`namespaces`) read with status `ok`. Both maps (deprecation, app-repo) were generated successfully
since the configured paths (`preflight-config/deprecation-map.json`,
`preflight-config/app-repo-map.json`) did not exist.
