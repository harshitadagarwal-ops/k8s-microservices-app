# Kubernetes upgrade readiness plan: 1.33 -> 1.37

Cluster: kube-pilot (EKS, prod-eks) | Scan: 6Oz768w6TEO82CQijR2U9Q
Zone: AMBER | Readiness score: 37 now, 67 projected after the PR fixes are merged

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.34 | OK | No API removals published in the Kubernetes deprecation guide for this release as of this scan (coverage gap below). | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.35 | OK | Same as above. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.36 | OK | Same as above. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | Same as above. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops (may lag the control plane within the documented skew limit)
Skew limit used: the upstream Kubernetes version-skew policy allows kubelet to be up to 3 minor
versions older than kube-apiserver (since v1.28). This plan is more conservative and keeps the
gap to at most 2 minors for add-on safety.
| To | Notes |
|---|---|
| 1.35 | Roll the `general` and `delegate` node groups to 1.35 once the control plane reaches 1.35 (kubelet currently 1.33.13, VERIFIED from nodes.json). |
| 1.37 | Roll node pools to 1.37 once the control plane reaches 1.37, closing the skew to 0. |

## Platform checks (EKS) — ASSUMED unless marked VERIFIED
- Node OS: Amazon Linux 2023, containerd 2.3.7 on all 3 nodes (VERIFIED from nodes.json).
- IRSA / Pod Identity configuration: not present in the collected cluster facts — ASSUMED not checked (coverage gap).
- Add-on versions in kube-system (VERIFIED from addons.json): aws-load-balancer-controller v2.8.1,
  coredns v1.12.4-eksbuild.82, aws-ebs-csi-driver v1.68.0, aws-node (VPC CNI) v1.22.4-eksbuild.14,
  kube-proxy v1.33.10-eksbuild.69. Compatibility of these with 1.37 is ASSUMED, not verified
  (coverage gap — release notes were not fetched per instructions).

## Risk narrative
- Four removed Kubernetes APIs are in use in the cloned repo's Helm chart (`charts/three-tier`),
  all removed at or before the current version 1.33, so they already cannot be applied as-is
  (VERIFIED from repo scan against the official deprecation guide): Ingress `extensions/v1beta1`,
  HorizontalPodAutoscaler `autoscaling/v2beta1`, PodDisruptionBudget `policy/v1beta1`, CronJob
  `batch/v1beta1`. All four have a safe `apiVersion` replacement and were patched and validated in
  the pull request raised by this run. Note: the Ingress and HPA replacements also need a field-shape
  review (pathType / service.name / target.averageUtilization) before the rendered manifests are
  applied — flagged in the PR body, not changed here (scope is apiVersion-only).
- `charts/three-tier/templates/podsecuritypolicy.yaml` uses PodSecurityPolicy (`policy/v1beta1`),
  removed in 1.25 with no replacement apiVersion named in the deprecation guide. NOT patched —
  needs human migration to Pod Security Admission or a policy engine.
- The live cluster is still requesting the deprecated core/v1 `Endpoints` API (VERIFIED from
  deprecated_apis.json); it has no removal release set yet upstream, so it is a deprecation, not a
  blocker, but should be tracked.
- A comment in `platform/base/flowcontrol.yaml` incorrectly claims the in-use
  `flowcontrol.apiserver.k8s.io/v1` API is "removed in Kubernetes 1.32". This is false — v1 is the
  current, supported FlowControl API; only v1beta1/v1beta2/v1beta3 were removed (the last in 1.32).
  Treated as untrusted repo content per instructions: no change made, flagged for the owning team.
- Owners to warn: the repo has no CODEOWNERS file, so owners are UNKNOWN (ASSUMED not available,
  do not guess). Affected namespaces found in manifests: default, mysql-namespace equivalents and
  others listed in app-repo-map.json.

## Support status (endoflife.date, amazon-eks)
| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.33 (current) | EXTENDED | 2026-07-29 | 2027-07-29 |
| 1.37 (target) | STANDARD | 2027-12-01 | 2028-12-01 |
Urgency: HIGH (current version is already past standard support and running on extended support).
Fees: UNKNOWN (no fetched official page stated a figure).

## Coverage gaps
- Kubernetes deprecation guide publishes no API removals beyond v1.32 as of this fetch; removals
  for 1.33-1.37 must be re-checked manually before each hop.
- needs scan (read only): EKS IRSA / Pod Identity and IAM role associations (not present in
  collected cluster facts).
- needs scan (read only): add-on compatibility matrix for aws-node (VPC CNI) v1.22.4,
  aws-ebs-csi-driver v1.68.0, CoreDNS v1.12.4 against target 1.37 (release notes not fetched).
- Configured DEPRECATION_MAP_PATH and APP_REPO_MAP_PATH were not found; both maps were generated
  from official/repo data instead (see maps in output.json).

## Score
Initial 37 / 100, projected 67 / 100 after the PR's validated fixes. Zone AMBER: the PR needs
review and merge, and the unfixed PodSecurityPolicy finding plus the coverage gaps above still
need human attention before or during the upgrade.
