# Kubernetes upgrade plan: 1.32 -> 1.33

Cluster `kube-pilot` | EKS | prod-eks | scan `xtYTucLNQh-EJMRPWVl_DA`
Readiness: **AMBER** — score 50 now, 80 after the fixes in this PR (needs PR review and merge).

## Control plane track (every minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | FLAGGED | Single hop. Two removed-API findings below are fixed by this PR; Argo CD ordering, Terraform drift and Endpoints-polling findings still need human resolution first. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool track (may lag within the version-skew limit)

Skew limit used: the Kubernetes version-skew policy allows kubelet to trail the control plane by
up to 3 minor versions, so a node pool does not have to roll on every control-plane hop.

| To | Notes |
|---|---|
| 1.33 | EKS managed node group `general` (AL2023_x86_64_STANDARD, 2 ready nodes, arm64, kubelet v1.32.13 — VERIFIED from nodes.json) rolls to 1.33 after the control-plane hop. Not strictly blocking for a single hop, but recommended to keep add-on compatibility current. |

## Platform checks (EKS)

- IRSA: `aws-ebs-csi-driver` IRSA role and `three-tier-backend` service-account role-arn are configured (VERIFIED from infra/eks/eks.tf and values-prod-eks.yaml); EKS Pod Identity is not in use — ASSUMED no action needed for this hop.
- Node AMI: AL2023_x86_64_STANDARD, per eks.tf comment "valid on 1.32..1.36" — ASSUMED compatible with 1.33 (not independently verified against AWS docs).
- Managed add-ons live on the cluster (VERIFIED from addons.json): coredns v1.11.4-eksbuild.104, kube-proxy v1.32.13-eksbuild.72, vpc-cni (aws-node) v1.22.4-eksbuild.14, aws-ebs-csi-driver v1.68.0, aws-load-balancer-controller v2.8.1. Their compatibility with EKS 1.33 was not fetched (listed as a coverage gap) — ASSUMED fine pending verification against https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html.
- CRDs served by `networking.k8s.io/vpc.k8s.aws` and `elbv2.k8s.aws` groups (VERIFIED from crds.json) are vendor CRDs, not core Kubernetes APIs scheduled for removal; no action needed for this hop.

## Risk narrative

- VERIFIED (repo scan): `charts/three-tier/templates/backend-pdb.yaml` used `policy/v1beta1` PodDisruptionBudget, removed in Kubernetes 1.25 — **fixed in this PR** to `policy/v1`.
- VERIFIED (repo scan): `charts/three-tier/templates/frontend-hpa.yaml` used `autoscaling/v2beta2` HorizontalPodAutoscaler, removed in Kubernetes 1.26 — **fixed in this PR** to `autoscaling/v2`.
- VERIFIED (live scan): `deprecated_apis.json` is empty — no client is currently requesting a removed/deprecated API against the live cluster.
- ASSUMED: the two CronJobs below may not be deployed live yet (the `default` namespace exists but add-on scanning only covers kube-system/well-known namespaces; the `reporting` namespace does not appear in `namespaces.json` at all), which is consistent with the empty live finding above.
  - `platform/base/legacy-endpoints-cronjob.yaml` — CronJob polls `core/v1 Endpoints` every 5 minutes; not patched (it is a script argument, not a manifest `apiVersion` field) — needs human review to migrate to `discovery.k8s.io/v1` EndpointSlices.
  - `platform/service-inventory/base/cronjob.yaml` — same pattern, polls `/api/v1/endpoints` via curl — needs human review.
- VERIFIED (repo comment, `platform/argocd/kustomization.yaml`): Argo CD is pinned to v2.14.0, tested only on Kubernetes 1.28-1.31, already outside its tested range on this cluster's current 1.32. The repo's own comment recommends a staged upgrade: v2.14.0 -> v3.4 (tested 1.32-1.35) -> v3.5 (tested 1.33-1.36). Not patched (version bump, out of scope for an automated fix) — needs human review before or alongside this hop.
- VERIFIED (repo): `infra/eks/terraform.tfvars` and `infra/eks/variables.tf` set `cluster_version = "1.34"`, which matches neither the live cluster (1.32.13, VERIFIED from cluster_version.json) nor the requested target (1.33). Not patched (a Terraform version bump is a live-affecting change, out of scope) — needs human review to decide the correct target before any `terraform apply`.
- Owners to warn: CODEOWNERS was not found in this repo, so per-namespace owners are **unknown** (not guessed). Namespaces with manifests in this repo: default, kube-system (plus platform/service-inventory targets a `reporting` namespace that does not exist live).

## Support status

| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.32 (current) | EXTENDED | 2026-03-23 | 2027-03-23 |
| 1.33 (target) | EXTENDED | 2026-07-29 | 2027-07-29 |

Source: https://endoflife.date/api/amazon-eks.json. Both the current and target versions already
passed standard support and are running on AWS Extended Support (paid) as of 2026-11-16 — urgency
**CRITICAL**. Fees are UNKNOWN (no official AWS pricing page was fetched; do not infer a dollar figure).
This hop alone does not return the cluster to standard support; plan further hops past 1.33 soon after.

## Coverage gaps

- AWS EKS managed-addon version compatibility matrix for 1.33 (coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver) was not fetched — verify before the hop.
- Live deployment status of the two Endpoints-polling CronJobs is unconfirmed (see Risk narrative above).

## Score

Initial 50 (100 minus 15+15 removed-API, 4 Argo CD ordering, 3+3 deprecated-Endpoints-in-use, 5 Terraform drift, 5 coverage gap).
Projected 80 after this PR's two validated, fixed removed-API findings (+30). Zone: **AMBER** — needs PR review and merge, plus human resolution of the remaining blockers above before the hop is applied.
