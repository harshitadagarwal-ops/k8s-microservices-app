# Kubernetes upgrade plan: 1.34 to 1.35

Cluster `prod-eks` (EKS), target env `prod-eks`, scan `puATvNhRQ7GNF3xTMTl0bg`.
Readiness: **AMBER** — initial score 77, projected 92 after the fixes in the pull request.
Plan only: nothing was upgraded, applied, or synced against the live cluster.

## Control plane track (one hop per minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.35 | FLAGGED | Single hop 1.34 -> 1.35. The removed-API blocker (flowcontrol v1beta3) is fixed in the accompanying PR. Two items remain for human review: core/v1 Endpoints usage (deprecated, not removed) and a stale Terraform `cluster_version` default. | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md |

EKS platform notes: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

## Node pool track

Skew limit used: Kubernetes version skew policy (v1.28+) — kubelet may be up to 3 minor versions
older than kube-apiserver, so nodes are never required to roll ahead of the control plane.

| To | Notes |
|---|---|
| 1.35 | Nodes (kubelet v1.34.12-eks) already match the current control-plane minor. AL2023 node AMI is documented in `infra/eks/eks.tf` as valid through 1.36 (ASSUMED from that comment, not independently verified). EKS add-ons (`coredns`, `kube-proxy`, `vpc-cni`, `aws-ebs-csi-driver`) are left unpinned in `cluster_addons = {}`, so EKS resolves compatible builds automatically on the next node/add-on refresh — verify the resulting versions after the hop (ASSUMED). |

## Platform checks (EKS)

- IRSA is in use (`values-prod-eks.yaml`: `eks.amazonaws.com/role-arn` annotation) — VERIFIED from the repo, compatible with 1.35.
- Node AMI/runtime: Amazon Linux 2023, containerd 2.3.7 — VERIFIED from `nodes.json`, no action needed.
- EKS module version (`terraform-aws-modules/eks` 20.31.6) support for 1.35 was not checked against the registry (out of the allowed-domain list) — ASSUMED compatible, confirm before applying.
- Cloud API / control-plane log shipping and KMS encryption are explicitly disabled in `infra/eks/eks.tf` (account role lacks the permissions) — VERIFIED from the repo comment, unrelated to the version hop but worth noting for the change record.

## Risk narrative

1. **VERIFIED (repo + map).** `flowcontrol.apiserver.k8s.io/v1beta3` (`FlowSchema`, `PriorityLevelConfiguration`) was removed in Kubernetes 1.32 per the official deprecation guide. It was still present in `platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/flowschema.yaml` and `platform/flowcontrol/base/prioritylevel.yaml`. Fixed in the accompanying PR by swapping to `flowcontrol.apiserver.k8s.io/v1` (no other content changed). This is a correctness blocker, not just a 1.35 concern — the live cluster is already on 1.34.
2. **VERIFIED (live scan).** `deprecated_apis.json` shows the live API server recording requests for the core/v1 `Endpoints` resource with no removal version set. `platform/base/legacy-endpoints-cronjob.yaml` and `platform/service-inventory/base/cronjob.yaml` are the source (both poll `kubectl get endpoints` / `GET /api/v1/endpoints` every 5 minutes). The deprecation guide offers no apiVersion-level replacement (the fix is migrating the client to `discovery.k8s.io/v1` `EndpointSlice`), so this was left unpatched and flagged for human review.
3. **VERIFIED (repo).** `infra/eks/variables.tf` defines `variable "cluster_version" { default = "1.32" }`, but `cluster_version.json` shows the live server at `v1.34.11-eks`. Terraform state and the declared default have drifted; left unpatched (out of the safe-fix scope, which is limited to apiVersion swaps) and flagged for human review before the next `terraform apply`.
4. **ASSUMED.** EKS-managed add-on versions (coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver) are unpinned in Terraform, so their 1.35-compatible builds will be chosen by EKS rather than this repo; not independently verified against AWS's compatibility matrix.

## Owners to warn

The repo has no CODEOWNERS file (checked `CODEOWNERS`, `.github/CODEOWNERS`, `docs/CODEOWNERS`) — owners are
**unknown**; do not guess. The generated app-repo map found 6 namespaces in-cluster-relevant manifests
(`default`, `demo`, `harness-delegate-ng`, `harness-preflight`, `kube-node-lease`, `kube-public`,
`kube-system`) all attributed to the single cloned repo `k8s-microservices-app`.

## Coverage gaps

None. All six cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`,
`namespaces`) reported `status: ok`, and both the deprecation map and the app-repo map were built
successfully (generated, since the configured map paths did not exist on disk).

## Score

- Deductions: removed API in use (flowcontrol v1beta3, fixed) -15; deprecated-not-removed API in use
  (core/v1 Endpoints, unfixed) -3; platform prerequisite not met (Terraform `cluster_version` drift,
  unfixed) -5. Total -23.
- Initial: 100 - 23 = **77**. Projected after the PR's validated fix: 77 + 15 = **92**.
- Zone: **AMBER** (initial < 85, projected >= 60 — needs PR review and merge).

## Support status

- Kubernetes 1.34 (current): STANDARD support, standard support ends 2026-12-02, extended support
  ends 2027-12-02 (endoflife.date `amazon-eks`, fields `eol` and `extendedSupport`). Fee: UNKNOWN (not
  published on a fetched official page).
- Kubernetes 1.35 (target): STANDARD support, standard support ends 2027-03-27, extended support ends
  2028-03-27. Fee: UNKNOWN.
- Urgency: **HIGH** — the current version's standard support ends 2026-12-02, 33 days from today
  (2026-10-30), inside the 90-day HIGH threshold.
