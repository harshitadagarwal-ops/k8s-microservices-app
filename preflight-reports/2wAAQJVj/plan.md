# Kubernetes upgrade plan: 1.32 -> 1.35

Cluster `kubepilot` | EKS | prod-eks | scan `2wAAQJVjTN6Scn0RF3EJlA`

Readiness: **AMBER** — initial score 50/100, projected 80/100 after the fixes in the pull request (needs PR review and merge, then re-scan).

## Control plane hops (every minor)

| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | FLAGGED | PodSecurityPolicy manifest (`charts/three-tier/templates/podsecuritypolicy.yaml`, enabled in `values-prod-eks.yaml`) uses `policy/v1beta1`, already removed in 1.25 — VERIFIED already broken on today's server version v1.32. Must be migrated to Pod Security Admission or an external policy controller before this or any hop. | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.33.md |
| 1.34 | OK | No further removed-API findings in the repo scan or the kubernetes.io deprecation guide (VERIFIED, highest documented removal release is 1.32). ASSUMED: EKS add-on compatibility holds — not verified (coverage gap). | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md |
| 1.35 | OK | No further removed-API findings documented (VERIFIED against the deprecation guide). ASSUMED: confirm EKS add-on versions (ALB controller v2.8.1, CoreDNS v1.11.4-eksbuild.104, EBS CSI v1.68.0, VPC CNI v1.22.4, kube-proxy) meet the minimum required for 1.35 — see AWS EKS release notes. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops

Skew limit used: kubelet may be up to 3 minor versions behind kube-apiserver (Kubernetes version-skew policy, extended skew policy effective since v1.28).

| To | Notes |
|---|---|
| 1.32 (hold) | Node pools (VERIFIED kubelet v1.32.13-eks on both nodes) may remain while the control plane moves to 1.33 and 1.34 — skew of 1-2 minors, within the 3-minor limit. |
| 1.35 | Node pools must reach at least 1.32 by the time the control plane hits 1.35 to stay within the 3-minor skew limit (skew would already be at the max of 3). ASSUMED best practice: roll node pools to 1.35 immediately after the final control-plane hop to minimize time at max skew. |

## Platform checks (EKS) — mostly ASSUMED, no cloud API access

- IRSA / Pod Identity: ASSUMED fine — recent repo history shows a rebuild "with v3 IRSA role names" for this cluster; not independently re-verified from cluster facts (no IAM data in the scan).
- `infra/eks/variables.tf` default `cluster_version` is `"1.34"` while `infra/eks/terraform.tfvars` pins `cluster_version = "1.32"` (VERIFIED from repo) — the tfvars value matches the live server version; the variable default is stale relative to both current and target and should be reviewed by a human when wiring the Terraform upgrade, but this is not a live blocker today.
- etcd / kubeadm: not applicable (EKS-managed control plane).

## Risk narrative

- VERIFIED (from the scan): server version v1.32.13-eks; 2 nodes, both kubelet v1.32.13-eks, containerd 2.3.7, Amazon Linux 2023, ready; `deprecated_apis.json` live scan returned **no** removed/deprecated API calls currently being made against the API server.
- VERIFIED (from the repo scan): `charts/three-tier` (used by `values-prod-eks.yaml`, i.e. the `prod-eks` target environment) renders 4 manifests on removed Kubernetes API versions: Ingress (`extensions/v1beta1`), HorizontalPodAutoscaler (`autoscaling/v2beta1`), CronJob (`batch/v1beta1`), and PodSecurityPolicy (`policy/v1beta1`). The first three have replacements in the kubernetes.io deprecation guide and were patched and validated in this run (apiVersion string only — no image, values, or other field changes). PodSecurityPolicy has no direct replacement and needs human review.
- ASSUMED: the Ingress `backend.serviceName`/`servicePort` fields and the HPA `targetAverageUtilization` metric field use the old schema shape; only the `apiVersion` line was patched (per the agent's change-nothing-else scope), so a human should confirm these still validate against the new API's schema before merging to a live environment.
- VERIFIED (from the repo): other manifest sets (`manifests/`, `manifests-eks/`, `argocd/*`, `gitops/*`) already use current, non-deprecated API versions.
- Owners to warn: the app-repo map found no `CODEOWNERS` file in this repo, so owners are **unknown** — do not guess; route the PR to whoever owns `charts/three-tier` by other means.

## Support status

- Current (1.32): EXTENDED support — standard support ended 2026-03-23, extended support ends 2027-03-23 (endoflife.date, product amazon-eks).
- Target (1.35): STANDARD support — standard support ends 2027-03-27, extended support ends 2028-03-27.
- Fees: UNKNOWN — no official AWS pricing page was fetched for EKS extended support.
- Urgency: MEDIUM (current version's active support period, extended support, ends 2027-03-23 — about 127 days from today, within 180 days but outside 90).

## Coverage gaps

- EKS add-on minimum-version compatibility with target 1.35 not verified — this agent has no cloud API access to the AWS EKS compatibility/release-notes APIs.

## Pull request

Raised right after this plan was built — see section 10 output / `output.json.prs` for the link. Fixes apiVersion only in `charts/three-tier/templates/{admin-ingress,backend-hpa,mysql-backup-cronjob}.yaml`. `podsecuritypolicy.yaml` is flagged for manual migration, not patched.

Plan only — nothing in the cluster was upgraded, scaled, restarted, or otherwise modified.
