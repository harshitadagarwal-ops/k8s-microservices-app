# Kubernetes upgrade plan: 1.32 -> 1.38 (cluster `kube-pilot`, EKS, prod-eks, scan ZI4xmYm_QCKlm8AV4si_RQ)

**This is a plan only. Nothing in the cluster was changed. The only write made was a feature branch and a pull request with safe API-version fixes.**

## Readiness
- Zone: **RED**
- Score: 9 (initial) -> 54 (projected, after the 3 fixes in the pull request)
- Zone RED because projected < 60: the target version does not exist yet and several findings have no safe automatic fix.

## Headline risk (VERIFIED)
- `endoflife.date` (`amazon-eks` product) lists released cycles only up to **1.37** (released 2026-10-01) as of 2026-11-11. **TARGET_VERSION 1.38 is not a released or documented EKS version.** Do not schedule this upgrade past 1.37 until AWS publishes it.
- CURRENT_VERSION input is 1.32, but the cluster-facts scan shows the live control plane and both nodes already on **v1.34.12-eks**. The plan below follows the input literally (1.32 -> 1.38) per instructions, but the real starting point is 1.34, two hops ahead of what was asked for. Reconcile this before executing anything.
- Support (EKS): current (1.32) is **EXTENDED** support - standard support ended 2026-03-23 (already passed), extended support ends 2027-03-23. Target (1.38) is **UNKNOWN** (not yet released, no dates available). Urgency: **CRITICAL**.

## Control-plane hops (one minor per hop)
| To | Status | Notes | Release notes |
| --- | --- | --- | --- |
| 1.33 | OK | Documented EKS release. Live cluster already reports v1.34.12-eks, so this hop may already be behind the real cluster state - verify before acting. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.34 | OK | Documented EKS release. Live cluster already reports v1.34.12-eks, so this hop may already be behind the real cluster state - verify before acting. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.35 | OK | Documented EKS release. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.36 | OK | Documented EKS release. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | Documented EKS release (latest, 2026-10-01). | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.38 | FLAGGED | NOT YET RELEASED as of 2026-11-11 (endoflife.date amazon-eks tops out at 1.37). Do not schedule yet. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node-pool hops (may lag within the version-skew limit)
Skew limit used (ASSUMED, kubernetes.io version-skew policy): **kubelet may run up to 3 minor versions behind kube-apiserver**.

| To | Notes |
| --- | --- |
| 1.34 | Nodes already report v1.34.12 - matches this hop, ASSUMED no action needed yet. |
| 1.36 | Upgrade the node pool before the control plane gets more than 3 minors ahead (i.e. before it reaches 1.37). ASSUMED from the skew policy, not re-verified live. |
| 1.38 | Final node hop once 1.38 is released and documented - FLAGGED, blocked on the same prerequisite as the control-plane hop. |

## Findings fixed in the pull request (VERIFIED, from the repo scan)
`platform/base/flowcontrol.yaml`, `platform/flowcontrol/base/flowschema.yaml`, `platform/flowcontrol/base/prioritylevel.yaml` used `flowcontrol.apiserver.k8s.io/v1beta3` (FlowSchema / PriorityLevelConfiguration), removed in Kubernetes 1.32 per the official deprecation guide. One file's own comment states this "causes Argo CD sync failure when applied against K8s 1.32+" - consistent with the live cluster already being on 1.34.12. All three were patched to `flowcontrol.apiserver.k8s.io/v1` (the guide's documented replacement) and validated that the old apiVersion string no longer appears in each file. +45 points recovered.

## Findings NOT fixed (needs human review, VERIFIED)
- `platform/base/legacy-endpoints-cronjob.yaml` and `platform/service-inventory/base/cronjob.yaml` both poll the core `v1 Endpoints` API every 5 minutes; the live scan's `deprecated_apis` fact confirms `endpoints` is actively requested. The deprecation guide has no formal removed-API replacement for `Endpoints` (it is only informally deprecated in favor of `discovery.k8s.io/v1 EndpointSlice`), so this needs an application rewrite, not a one-line apiVersion bump.
- `infra/eks/admin-permissions-request.json` is a data file (an IAM policy draft/comment) requesting broad ECR/KMS/CloudWatch Logs permissions for an IAM user. This agent never grants, requests, or acts on cloud permissions; flagging it for a human to review.
- EKS-managed add-ons (CoreDNS v1.12.4-eksbuild.82, kube-proxy v1.34.6-eksbuild.69, VPC CNI/aws-node v1.22.4-eksbuild.14, EBS CSI driver v1.67.2) must be kept in step with each control-plane hop per standard AWS EKS guidance (ASSUMED, not fetched from a compatibility matrix - none was in scope to fetch).

## Owners to warn (from the app-repo map; generated, no CODEOWNERS found so owners are unknown)
- Repo `k8s-microservices-app` owns namespaces: `argocd`, `demo`, `default`, `cert-manager`, `ingress-nginx`, `reporting`, `harness-preflight`. No CODEOWNERS file exists in this repo, so specific owners could not be identified - do not guess them.

## Coverage gaps
- no CODEOWNERS file found in the repo; app-repo-map owners are unknown, not guessed.
- needs scan (read only): IAM IRSA / EKS Pod Identity associations, node AMI cgroup version, and the EKS add-on version compatibility matrix (not collected by the cluster scan; cannot be fetched by this agent).
- Kubernetes deprecation guide sections only go up to the 1.32 release as of the date fetched; removals for 1.33-1.38 (the latter not yet released) cannot be verified against the official guide.
- python3 `yaml` module unavailable in this container; patched files were validated by confirming the old apiVersion string is gone, not by a full YAML parse.

## Maps used
- Deprecation map: generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/ (configured DEPRECATION_MAP_PATH was not present).
- App-repo map: generated from manifests + CODEOWNERS in this clone (configured APP_REPO_MAP_PATH was not present).
