# Kubernetes upgrade plan: 1.34 -> 1.35

Cluster `kube-pilot` | EKS | prod-eks | scan `dQnnFzTtREKOn82u4SB8vw`

Readiness: **AMBER** — initial score 82/100, projected 97/100 after the companion PR is merged.
Plan only: nothing was upgraded on the live cluster.

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.35 | FLAGGED | Single hop. Blocked on merging the companion PR (removes removed `flowcontrol.apiserver.k8s.io/v1beta3`) and on human migration of the legacy Endpoints poller. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops
Skew limit used: kubelet may lag the control plane by up to 3 minor versions (Kubernetes
version-skew policy, extended from 2 to 3 starting with the 1.28 release).

| To | Notes |
|---|---|
| 1.35 | Node pool `general-...08` is currently at kubelet v1.34.12 (VERIFIED, matches control plane). Because this is a single-minor hop and well inside the skew limit, the node pool can move in the same change window as the control plane, or trail by one hop if a canary approach is preferred. |

## Platform checks (EKS) — ASSUMED unless noted
- IRSA / Pod Identity: not directly observable from the collected facts (no cloud IAM API access); addon
  pods (`aws-load-balancer-controller`, `ebs-csi-controller`, `aws-node`) are present and running, which is
  consistent with IRSA/Pod Identity already being configured. **ASSUMED**.
- VPC CNI (`aws-node` v1.22.4-eksbuild.14) and EBS CSI driver (`v1.67.2`) are present (**VERIFIED** from
  `addons.json`); compatibility with control plane 1.35 was not checked against AWS's EKS add-on compatibility
  matrix (no fetch of that page was made per instructions). **ASSUMED compatible**, recommend confirming in
  the AWS console before the hop.
- Node OS: Amazon Linux 2023 (**VERIFIED** from `nodes.json`); cgroup v2 is default on AL2023, consistent
  with modern kubelet requirements. **ASSUMED** no cgroup driver changes needed.

## Risk narrative
1. **Removed API in use (repo), fixed in this PR** — `flowcontrol.apiserver.k8s.io/v1beta3`
   (`FlowSchema`, `PriorityLevelConfiguration`) was removed in Kubernetes 1.32, which is at or before the
   1.35 target. **VERIFIED** (repo grep + official deprecation guide). Found in
   `platform/flowcontrol/base/flowschema.yaml`, `platform/flowcontrol/base/prioritylevel.yaml`, and
   `platform/base/flowcontrol.yaml` (3 occurrences). Patched to `flowcontrol.apiserver.k8s.io/v1` in the
   companion PR; validated that the old apiVersion no longer appears in any of the three files.
2. **Deprecated (not yet removed) API in active use, needs human review** — core `v1` `Endpoints` API is
   being queried live every 5 minutes by `legacy-report-client-sa` / the `legacy-endpoints-report` CronJob
   (`platform/base/legacy-endpoints-cronjob.yaml`). **VERIFIED** both from the repo and from the cluster's
   `deprecated_apis.json` scan (`group: "", version: v1, resource: endpoints`). The deprecation guide gives
   no `replace_with` apiVersion for this (it is an application-level call, not a manifest apiVersion), so it
   was left unpatched and is the top blocker. Recommended remediation: change the CronJob's
   `kubectl get endpoints` command to read `discovery.k8s.io/v1` `EndpointSlice` objects instead.

## Owners to warn
The app-repo map was generated (no `APP_REPO_MAP_PATH` file and no `CODEOWNERS` file found in the repo), so
owners are **unknown**. Namespaces found in manifests: `default`, `demo`, `mysql` (via Helm chart),
`reporting` (referenced by the `batch-reporting` FlowSchema), plus platform namespaces. Whoever owns the
`default` namespace workloads (home of `legacy-endpoints-report` and `demo-batch-priority`/`batch-reporting`
flow-control objects) should review the PR.

## Support status
- Current (1.34): STANDARD, standard support ends 2026-12-02, extended support ends 2027-12-02. Urgency
  **HIGH** (standard support ends within 90 days of today, 2026-11-11).
- Target (1.35): STANDARD, standard support ends 2027-03-27, extended support ends 2028-03-27.
- Fees: UNKNOWN (no official page stating EKS version-specific fees was fetched).

## Coverage gaps
None — all six cluster fact files (`cluster_version`, `nodes`, `deprecated_apis`, `addons`, `crds`,
`namespaces`) returned `status: ok`.

## Maps used
- Deprecation map: generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/
  (37 entries) because `DEPRECATION_MAP_PATH` was not present.
- App-repo map: generated from manifests + CODEOWNERS search (none found) because `APP_REPO_MAP_PATH` was
  not present.
