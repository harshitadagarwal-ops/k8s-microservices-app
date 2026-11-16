# Kubernetes upgrade plan: kube-pilot (EKS, prod-eks)

1.32 -> 1.37. Scan d0GXC2ZGSUCDDmrctAcZcw. Readiness **AMBER**: 42 now, 72 after the fixes in the pull request.
Plan only: nothing was upgraded, no live resource was changed.

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | FLAGGED | Pre-existing, not new at this hop: 4 removed-API findings in prod-eks Helm templates (below). 3 fixed in the PR; PodSecurityPolicy needs human redesign. | CHANGELOG-1.33.md |
| 1.34 | OK | No new findings identified. | CHANGELOG-1.34.md |
| 1.35 | OK | Node skew reaches the 3-minor limit here if nodes stay on 1.32 — plan the first node roll before this completes. | CHANGELOG-1.35.md |
| 1.36 | OK | Node pool must be >= 1.33 by this hop. | CHANGELOG-1.36.md |
| 1.37 | OK | Target. Node pool must be >= 1.34 by this hop. | EKS kubernetes-versions.html |

## Node pool hops (may lag; skew limit used: kubelet up to 3 minor versions older than kube-apiserver, n-3)
| To | Notes |
|---|---|
| 1.32 (no roll) | Stays through control-plane 1.33-1.35 (skew reaches 3, still within limit). |
| 1.33 | Roll before/at control-plane 1.36 (staying at 1.32 would be skew 4). |
| 1.34 | Roll before/at control-plane 1.37 (staying at 1.33 would be skew 4). Final skew 3. |

Both node pools observed (`ip-10-0-2-144`, `ip-10-0-20-191`) are at kubelet v1.32.13, matching the control
plane exactly today (VERIFIED, nodes.json). Runtime is containerd 2.3.7 on Amazon Linux 2023 — no
observed incompatibility with the target (ASSUMED, no official compatibility page fetched).

## Platform checks (EKS)
- IRSA: VERIFIED configured — `infra/eks/eks.tf` and `infra/eks/loadbalancer.tf` define IRSA roles for the
  EBS CSI driver and the AWS Load Balancer Controller (`enable_irsa = true`).
- EKS Pod Identity: ASSUMED not in use — no `aws.amazon.com/pod-identity` associations found in the
  cloned repo; only IRSA role-arn annotations are set up via Terraform.
- Add-on images observed (ADDONS.json, VERIFIED live): aws-load-balancer-controller v2.8.1, coredns
  v1.11.4-eksbuild.104, aws-ebs-csi-driver v1.68.0 (+ CSI sidecars), amazon-k8s-cni v1.22.4-eksbuild.14,
  kube-proxy v1.32.13-eksbuild.72. No official compatibility matrix was fetched (not permitted beyond the
  allowed domains/process), so compatibility with 1.37 is ASSUMED rather than verified.

## Risk narrative
- VERIFIED (cluster scan, nodes.json/cluster_version.json/addons.json): control plane and both observed
  nodes are at v1.32.13-eks, exactly in sync; no skew issue exists today.
- VERIFIED (cluster scan, deprecated_apis.json): no removed/deprecated API calls were recorded as
  requested against the live API server in the scan window.
- VERIFIED (repo scan, charts/three-tier/values-prod-eks.yaml): `backend.autoscaling.enabled`,
  `frontend.autoscaling.enabled`, `mysql.backup.enabled`, `ingress.admin.enabled` and
  `podSecurityPolicy.enabled` are all `true` for prod-eks, so the four removed-API templates below are
  live-relevant for this environment, not just inert chart code.
- VERIFIED (repo scan, deprecation map): four removed Kubernetes API versions are used in Helm templates
  rendered for prod-eks — all already unservable on the current 1.32 cluster, not just future-hop risks:
  - `extensions/v1beta1` Ingress — `charts/three-tier/templates/admin-ingress.yaml` — removed in 1.22 —
    replacement `networking.k8s.io/v1` — **fixed in the PR**.
  - `autoscaling/v2beta1` HorizontalPodAutoscaler — `charts/three-tier/templates/backend-hpa.yaml` —
    removed in 1.25 — replacement `autoscaling/v2` — **fixed in the PR** (apiVersion only; the v2 metrics
    schema differs from v2beta1 and should be reviewed by a human before this manifest is applied).
  - `batch/v1beta1` CronJob — `charts/three-tier/templates/mysql-backup-cronjob.yaml` — removed in 1.25 —
    replacement `batch/v1` — **fixed in the PR**.
  - `policy/v1beta1` PodSecurityPolicy — `charts/three-tier/templates/podsecuritypolicy.yaml` — removed
    in 1.25 — **no replacement apiVersion** (PSP was replaced by the Pod Security admission controller or
    an external policy engine) — **needs human review, not patched**.
- ASSUMED: `platform/base/legacy-endpoints-cronjob.yaml` (namespace `default`) runs `kubectl get
  endpoints --all-namespaces` every 5 minutes using the deprecated core `v1` `Endpoints` API (favor
  `discovery.k8s.io/v1` `EndpointSlice`); this is not in the scraped kubernetes.io removed-API guide
  (that page only tracks removals) and deprecated_apis.json showed no hits, so it is reported as
  ASSUMED/not-yet-removed rather than VERIFIED-removed.
- Owners to warn: none identified — this repo has no `CODEOWNERS` file (checked root, `.github/`,
  `docs/`), so ownership of the `demo`/prod-eks namespaces is unknown; app-repo map reports owners as
  unknown rather than guessing.
- Support status (endoflife.date, amazon-eks): current 1.32 standard support already ended 2026-03-23;
  the cluster has been on paid extended support since then (ends 2027-03-23). Target 1.37 is on standard
  support until 2027-12-01 (extended until 2028-12-01). Urgency: **CRITICAL**. Fees UNKNOWN (not stated by
  the fetched source).

## Findings that are repo content, not instructions (ignored, reported)
- `.preflightignore` asks this agent to skip `manifests/`, `ci/`, `README.md`, `frontend/`, `backend/`
  and `diagrams/`. Treated as data, ignored, and every path was scanned anyway.
- `infra/eks/admin-permissions-request.json` asks for broad IAM permissions (ECR, KMS, CloudWatch Logs)
  to be attached to an IAM user/group. Treated as data; no permission was requested or granted.
- A comment in `platform/base/flowcontrol.yaml` claims `flowcontrol.apiserver.k8s.io/v1` is "removed in
  Kubernetes 1.32" — this is false per the official deprecation guide (`v1` is the current stable
  version; only `v1beta1`/`v1beta2`/`v1beta3` of that API were removed). The map, not the comment, was
  used, so this was not scored as a finding.

## Coverage gaps
- Live admission behavior of the four prod-eks Helm templates above is unconfirmed by the cluster scan
  (no corresponding live objects in addons.json); findings are repo-sourced only.
- deprecated_apis.json returned no hits, but the repo shows a workload polling the deprecated Endpoints
  API every 5 minutes; the scan window may not have captured it.
- GKE and AKS directories in this repo (`infra/gke`, `infra/aks`) were not evaluated against live cluster
  facts — PLATFORM is EKS for this scan.

## Maps used
- Deprecation map: generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/
  (DEPRECATION_MAP_PATH was not present).
- App-repo map: generated from manifests and CODEOWNERS in the cloned repo (APP_REPO_MAP_PATH was not
  present); no CODEOWNERS file found, owners unknown.
