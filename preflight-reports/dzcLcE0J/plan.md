# Kubernetes upgrade readiness: 1.33 -> 1.37 (EKS, prod-eks, cluster kube-pilot)

## Readiness
ZONE: AMBER. Initial score 47/100, projected 62/100 after the fixes in this PR.
Nothing blocks the hop plan outright, but two repo findings need a human decision and
one platform check could not be verified from the collected scan facts.

## Control plane hops (every minor, VERIFIED against cluster_version.json = v1.33.13-eks)
| To | Status | Notes |
|---|---|---|
| 1.34 | OK | No removed-API findings from the deprecation map land on this hop. |
| 1.35 | OK | No removed-API findings land on this hop. Roll node pools to 1.35 right after. |
| 1.36 | OK | No removed-API findings land on this hop. Nodes at 1.35 (skew 1). |
| 1.37 | OK | Target. Roll node pools to 1.37 to close skew to 0. Re-run Preflight once the PodSecurityPolicy templates are resolved by a human. |

Release notes: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html (per hop).

## Node pool hops (ASSUMED skew limit: EKS/Kubernetes allows kubelet up to 3 minors behind kube-apiserver)
All 3 nodes currently report kubelet v1.33.13 (VERIFIED, nodes.json), matching the control plane.
Plan keeps the actual gap to at most 2 minors and reconciles twice instead of every hop:
| To | Notes |
|---|---|
| 1.33 (hold) | Hold through the 1.34 control-plane hop. |
| 1.35 | Roll general-* and delegate-* node pools after control plane reaches 1.35. |
| 1.37 | Roll node pools after control plane reaches 1.37. |

## Platform checks (EKS) - ASSUMED unless noted
- IRSA / Pod Identity: ASSUMED - service-account IAM annotations were not in the collected scan
  facts (coverage gap, 5 pts).
- Node OS/runtime: VERIFIED - Amazon Linux 2023, containerd 2.3.7 on all 3 nodes (nodes.json);
  no known incompatibility with 1.34-1.37.
- Core add-ons (VERIFIED from addons.json): aws-load-balancer-controller v2.8.1, VPC CNI
  (amazon-k8s-cni) v1.22.4, aws-network-policy-agent v1.4.0, CoreDNS v1.12.4, EBS CSI driver
  v1.68.0, kube-proxy v1.33.10. No incompatibility confirmed from the scan; this run did not fetch
  release notes to cross-check add-on compatibility, so treat as ASSUMED-OK pending the vendor's
  own add-on-version documentation before each hop.
- CRDs (VERIFIED from crds.json): 9 AWS-VPC-CNI/ELB CRDs, all at v1alpha1/v1beta1 custom (non-core)
  versions - not covered by the core Kubernetes deprecation guide, no finding.

## Repo findings and fixes (VERIFIED from grep of the cloned repo k8s-microservices-app)
Fixed in this PR (apiVersion swap only, per the deprecation guide's named replacement):
- charts/three-tier/templates/admin-ingress.yaml: extensions/v1beta1 -> networking.k8s.io/v1 (Ingress, removed 1.22)
- charts/three-tier/templates/backend-hpa.yaml: autoscaling/v2beta1 -> autoscaling/v2 (HPA, removed 1.25)
- charts/three-tier/templates/frontend-hpa.yaml: autoscaling/v2beta2 -> autoscaling/v2 (HPA, removed 1.26)
- charts/three-tier/templates/backend-pdb.yaml: policy/v1beta1 -> policy/v1 (PDB, removed 1.25)
- charts/three-tier/templates/mysql-pdb.yaml: policy/v1beta1 -> policy/v1 (PDB, removed 1.25)
- charts/three-tier/templates/mysql-backup-cronjob.yaml: batch/v1beta1 -> batch/v1 (CronJob, removed 1.25)

Needs human review (NOT patched - the deprecation guide names no replacement apiVersion):
- charts/three-tier/templates/podsecuritypolicy.yaml and podsecuritypolicy-mysql.yaml:
  policy/v1beta1 PodSecurityPolicy, removed in 1.25. Recommend Pod Security Admission labels or an
  OPA/Gatekeeper/Kyverno policy, then delete these templates.

Live cluster (VERIFIED from deprecated_apis.json): a client still requests core v1 Endpoints.
Kubernetes recommends EndpointSlice; upstream has not set a removal release for this, so it is
scored as deprecated-but-not-removed only (monitor, no action required before 1.37).

Owners to warn: CODEOWNERS was not found in k8s-microservices-app, so owners are unknown - route
the PR to whoever maintains charts/three-tier.

## Support status (VERIFIED from https://endoflife.date/api/amazon-eks.json)
- Current 1.33: status EXTENDED (standard support ended 2026-07-29; extended support ends 2027-07-29).
- Target 1.37: status STANDARD (standard support ends 2027-12-01; extended support ends 2028-12-01).
- Urgency: CRITICAL - standard support for 1.33 has already ended. Fees: UNKNOWN (no official fee
  page was fetched this run).

## Coverage gaps
- needs scan (read only): service-account IAM role annotations (IRSA/Pod Identity) for the EKS
  platform prerequisite check.

## Maps
- Deprecation map: configured path /harness/preflight-config/deprecation-map.json was absent;
  generated from https://kubernetes.io/docs/reference/using-api/deprecation-guide/ (37 entries).
- App-repo map: configured path /harness/preflight-config/app-repo-map.json was absent; generated
  from the cloned repo's manifests and CODEOWNERS (7 namespaces, owners unknown).
