# Kubernetes upgrade plan: kube-pilot (EKS, prod-eks)

1.32 -> 1.37, scan RCZ5ca0jR-qisPoh3vl66w

## Readiness
- initial score: 45 (AMBER overall; GREEN>=85, AMBER if projected>=60, else RED)
- projected score after the PR's 3 validated fixes merge: 75

## Control plane hops (every minor)
| To | Status | Notes |
|---|---|---|
| 1.33 | FLAGGED | First hop; carries forward the 3 unfixed/fixed-in-PR removed-API findings in charts/three-tier until the PR merges, and the add-on compatibility coverage gap applies to every hop. |
| 1.34 | OK | Verify EKS-managed add-on (CoreDNS, kube-proxy, VPC CNI, EBS CSI, AWS LB Controller) versions against the AWS EKS compatibility docs for this version before rolling (ASSUMED needed, not verified by this scan). |
| 1.35 | OK | Verify EKS-managed add-on (CoreDNS, kube-proxy, VPC CNI, EBS CSI, AWS LB Controller) versions against the AWS EKS compatibility docs for this version before rolling (ASSUMED needed, not verified by this scan). |
| 1.36 | OK | Verify EKS-managed add-on (CoreDNS, kube-proxy, VPC CNI, EBS CSI, AWS LB Controller) versions against the AWS EKS compatibility docs for this version before rolling (ASSUMED needed, not verified by this scan). |
| 1.37 | OK | Verify EKS-managed add-on (CoreDNS, kube-proxy, VPC CNI, EBS CSI, AWS LB Controller) versions against the AWS EKS compatibility docs for this version before rolling (ASSUMED needed, not verified by this scan). |

Release notes for every EKS hop: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html (AWS publishes one combined compatibility/release page, not per-version changelogs).

## Node pool hops (version-skew limit used: kubelet may lag kube-apiserver by up to 3 minor versions, n-3)
| To | Notes |
|---|---|
| 1.34 | Roll node pools (general, delegate) to 1.34 once control plane reaches 1.35, keeping kubelet within the documented n-3 version-skew limit used for this plan (kubelet may lag the API server by up to 3 minor versions). |
| 1.37 | Final node pool roll to 1.37 once control plane reaches 1.37, closing the skew to 0. Skew limit used: kubelet >= apiserver-3. |

## Platform checks (EKS) - derived from facts, ASSUMED where noted
- VERIFIED: all 3 nodes run containerd (no dockershim dependency), Amazon Linux 2023, arm64, kubelet v1.32.13 matching the v1.32.13-eks control plane. No current version skew.
- VERIFIED: crds.json shows no stored/served CRD version mismatch for any installed CRD (aws-load-balancer-controller and VPC resource CRDs).
- ASSUMED (ServiceAccount IRSA vs Pod Identity not collected by the facts scan): confirm every workload ServiceAccount's IAM binding (IRSA annotation or Pod Identity association) still resolves after the hops; this was not verified, see coverage gaps.
- ASSUMED: EKS-managed add-on versions (CoreDNS v1.11.4, kube-proxy v1.32.13, VPC CNI v1.22.4, EBS CSI v1.68.0, AWS Load Balancer Controller v2.8.1 -- from addons.json) will need bumping to versions compatible with 1.33-1.37 per the AWS EKS add-on compatibility docs; not verified against those docs (coverage gap), so no ordering deduction was applied, only a coverage-gap deduction.

## Risk narrative
- VERIFIED (repo scan): charts/three-tier/templates used three already-removed API versions -- extensions/v1beta1 Ingress (removed 1.22), autoscaling/v2beta1 HorizontalPodAutoscaler (removed 1.25), batch/v1beta1 CronJob (removed 1.25). These were not seen in the live deprecated_apis.json scan because this chart has not been synced to the cluster yet (added in a recent commit). All three were patched in the attached pull request to their 1.25+/1.22+ replacement apiVersion (networking.k8s.io/v1, autoscaling/v2, batch/v1); only the apiVersion field was changed, nothing else.
- VERIFIED (repo scan): policy/v1beta1 PodSecurityPolicy (charts/three-tier/templates/podsecuritypolicy.yaml) is enabled for prod-eks (values-prod-eks.yaml: podSecurityPolicy.enabled=true) and was removed in 1.25 with no replacement API. NOT patched automatically -- needs human migration to Pod Security Admission labels or an external policy controller (e.g. OPA Gatekeeper, Kyverno) before any hop past 1.24.
- VERIFIED (live scan): deprecated_apis.json is empty -- no removed/deprecated APIs are currently being requested against the live v1.32.13 control plane.
- VERIFIED (endoflife.date): current EKS 1.32 standard support ended 2026-03-23; cluster is now in the paid extended-support window until 2027-03-23 (127 days from today, 2026-11-16) -- urgency MEDIUM. Target 1.37 is in standard support until 2027-12-01.
- ASSUMED: EKS add-on minimum-version requirements per hop (coverage gap, not fetched from AWS docs within the tool budget).

## Owners to warn (from the app-repo map; repo k8s-microservices-app)
No CODEOWNERS file was found in the repo, so owners are unknown for every namespace (argocd, demo, default, cert-manager, ingress-nginx, reporting, harness-preflight). Route the pull request to whoever owns charts/three-tier and the prod-eks ArgoCD app (argocd/prod-eks/apps.yaml) manually.

## Coverage gaps
- needs scan (read only): EKS add-on/CRD minimum-version compatibility matrix for 1.33-1.37 (not fetched from AWS docs within tool budget)
- needs scan (read only): ServiceAccount IRSA annotations / EKS Pod Identity associations (not collected by the facts scan, so IRSA platform prerequisite is ASSUMED not verified)
