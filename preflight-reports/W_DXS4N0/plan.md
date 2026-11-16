# Kubernetes upgrade plan: 1.32 -> 1.37 (kube-pilot, EKS, prod-eks)

Scan W_DXS4N0RfmNjoPH65YNzQ. Zone **AMBER**. Readiness **45** now, **75** after the fixes in the
accompanying pull request. PLAN ONLY -- nothing was upgraded, no live resource was changed.

## Control plane hops (one minor at a time)
| To | Status | Notes |
|----|--------|-------|
| 1.33 | FLAGGED | Blocked today: the prod-eks PodSecurityPolicy manifest already fails against any 1.25+ API server (no PSP API). The 3 apiVersion fixes in this PR (Ingress, HPA, CronJob) must merge first. |
| 1.34 | OK | Re-verify add-on/CRD compatibility bundled with this EKS minor (coverage gap, not verified this run). |
| 1.35 | OK | Node pool may still lag at 1.32 here (skew 3, at the ASSUMED n-3 limit) -- verify before continuing. |
| 1.36 | OK | Node pool must roll to >=1.33 here to stay within the n-3 kubelet skew limit. |
| 1.37 (target) | OK | Confirm control plane healthy, then roll nodes to 1.37 to match. |

Release notes: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html (same page covers all EKS minors; no per-version anchor is published).

## Node pool track
Fewer rolls than the control plane, limited by the kubelet skew policy. **Skew limit used: n-3**
(kubelet may be up to 3 minor versions older than kube-apiserver, current Kubernetes version-skew
policy) -- ASSUMED, not re-fetched this run.
| To | Notes |
|----|-------|
| 1.32 (hold) | Stays at 1.32 through control-plane hops to 1.33/1.34/1.35 (lag 1,2,3 -- within the n-3 limit). |
| 1.35 | Roll when control plane reaches 1.36 (lag 1). |
| 1.37 | Roll when control plane reaches 1.37 (lag 0, matches target). |

## Platform checks (EKS) -- all ASSUMED unless marked VERIFIED
- IRSA / EKS Pod Identity: cannot be confirmed from node/add-on facts alone -- ASSUMED not verified; coverage gap, no cloud API read was requested.
- Node OS/runtime: VERIFIED from `nodes.json` -- Amazon Linux 2023, containerd 2.3.7, kubelet v1.32.13 matches the control plane today. No skew violation right now.
- Add-on versions (VERIFIED from `addons.json`): aws-load-balancer-controller v2.8.1, coredns v1.11.4-eksbuild.104, aws-ebs-csi-driver v1.68.0, aws-node (VPC CNI) v1.22.4, kube-proxy v1.32.13. Compatibility with 1.37 is a coverage gap (not fetched; release-note fetching is out of scope for this run).

## Risk narrative
- VERIFIED (repo scan, `charts/three-tier/templates/admin-ingress.yaml`): uses `extensions/v1beta1`
  Ingress, removed in Kubernetes 1.22. Enabled for prod-eks (`values-prod-eks.yaml: ingress.admin.enabled: true`).
  **Fixed in this PR** -> `networking.k8s.io/v1`, with `pathType: Prefix` and the v1 backend
  `service.name`/`service.port.number` shape.
- VERIFIED (repo scan, `charts/three-tier/templates/backend-hpa.yaml`): uses `autoscaling/v2beta1`
  HorizontalPodAutoscaler, removed in Kubernetes 1.25. Enabled for prod-eks (`backend.autoscaling.enabled: true`).
  **Fixed in this PR** -> `autoscaling/v2`, with `metrics[].resource.target.type/averageUtilization`.
- VERIFIED (repo scan, `charts/three-tier/templates/mysql-backup-cronjob.yaml`): uses `batch/v1beta1`
  CronJob, removed in Kubernetes 1.25. Enabled for prod-eks (`mysql.backup.enabled: true`).
  **Fixed in this PR** -> `batch/v1` (spec shape unchanged).
- VERIFIED (repo scan, `charts/three-tier/templates/podsecuritypolicy.yaml`): uses `policy/v1beta1`
  PodSecurityPolicy, removed in Kubernetes 1.25, **no replacement API** in the official deprecation
  guide. Enabled for prod-eks (`podSecurityPolicy.enabled: true`). **NOT patched** -- needs human
  redesign (Pod Security Admission labels or an OPA/Gatekeeper policy) before any further hop.
- VERIFIED (live scan, `deprecated_apis.json`): empty -- no live client is currently requesting a
  removed or deprecated API against the running 1.32 control plane.
- Two comments embedded in repo files (`platform/base/flowcontrol.yaml`: "F02: Using removed
  flowcontrol.apiserver.k8s.io/v1 API version... Removed in Kubernetes 1.32"; and
  `platform/base/legacy-endpoints-cronjob.yaml`: "Endpoints API is deprecated in Kubernetes 1.33")
  assert removals that do not match the official deprecation guide or the actual manifest content:
  the flowcontrol files already use `flowcontrol.apiserver.k8s.io/v1`, which is the *current*,
  non-deprecated version (the deprecation guide shows v1beta3 removed at 1.32, not v1); and the
  "legacy endpoints" file contains no `kind: Endpoints` object at all, only a ServiceAccount,
  RBAC objects and a CronJob reading the API via a shell command. Treated as untrusted repo data
  per the read-only/no-injection rule; ignored, no fix applied, flagged here for human review.

## Owners to warn
App-repo map found no CODEOWNERS file in this repo, so owners are **unknown** -- do not guess. Repo:
k8s-microservices-app. Namespaces found in manifests: default, demo, harness-delegate-ng,
harness-preflight, kube-node-lease, kube-public, kube-system.

## Support status
| Version | Status | Standard end | Extended end |
|---------|--------|--------------|--------------|
| 1.32 (current) | EXTENDED | 2026-03-23 | 2027-03-23 |
| 1.37 (target) | STANDARD | 2027-12-01 | 2028-12-01 |

Source: https://endoflife.date/api/amazon-eks.json (`eol` field used for standard end,
`extendedSupport` used for extended end). Monthly fees: UNKNOWN -- no official AWS pricing page was
fetched this run. Urgency: **CRITICAL** -- EKS 1.32 standard support already ended on 2026-03-23;
the cluster is running on paid extended support today (2026-11-16).

## Coverage gaps
- add-on/CRD compatibility matrix with target 1.37 not available from the scan (coredns,
  aws-ebs-csi-driver, aws-load-balancer-controller, aws-node/vpc-cni, kube-proxy).
- EKS platform prerequisites (IRSA vs EKS Pod Identity, OIDC provider) only ASSUMED from node/add-on
  facts, not verified via a cloud API read.

## Maps used
- Deprecation map: generated this run from https://kubernetes.io/docs/reference/using-api/deprecation-guide/
  (the configured DEPRECATION_MAP_PATH was missing).
- App-repo map: generated this run from manifests + CODEOWNERS in the cloned repo (the configured
  APP_REPO_MAP_PATH was missing).
