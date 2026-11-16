# Kubernetes upgrade plan: 1.32 -> 1.37 (EKS, prod-eks, cluster kube-pilot)

Scan wYB9k6keRhCSTtuZZ7VsBA | Readiness: **AMBER** (initial 46, projected 76 after the PR fixes)

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | OK | No repo-detected blockers at this hop | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.33.md |
| 1.34 | OK | No repo-detected blockers at this hop | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.34.md |
| 1.35 | FLAGGED | PodSecurityPolicy (policy/v1beta1) was removed in 1.25 and has no replacement API; it must already be migrated off before any hop at or above 1.25. Since current is 1.32, this is already a blocker now, flagged again here as a checkpoint | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md |
| 1.36 | FLAGGED | Node pool skew checkpoint: node pool must be rolled to at least 1.33 before or at this hop to stay within the n-3 kubelet skew limit | https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.36.md |
| 1.37 | FLAGGED | Node pool skew checkpoint: node pool must be rolled to at least 1.34 before or at this hop. Confirm EKS managed add-on versions support 1.37 before cutting over | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops (skew limit used: n-3, kubelet may trail kube-apiserver by up to 3 minor versions, Kubernetes 1.28+ policy, ASSUMED)
| To | Notes |
|---|---|
| 1.33 | Node pool track (skew limit used: Kubernetes n-3, kubelet may trail kube-apiserver by up to 3 minor versions as of Kubernetes 1.28+, ASSUMED general policy). Roll node pool 'general-20261115161132087800000008' to 1.33 before control plane reaches 1.36 to keep skew <= 3 |
| 1.34 | Roll node pool to 1.34 before control plane reaches 1.37 to keep skew <= 3. Further node rolls to fully close the gap with 1.37 are optional and can follow at the team's pace within the skew limit |

## Platform checks (EKS) - derived from scan, unverified items marked ASSUMED
- Node OS: Amazon Linux 2023 (arm64), containerd 2.3.7 - VERIFIED from nodes.json, compatible with 1.37.
- Single node pool `general-20261115161132087800000008`, 2 nodes, kubelet v1.32.13 matching control plane - VERIFIED.
- IRSA / Pod Identity: not in the cluster scan - ASSUMED unknown, see coverage gaps.
- EKS managed add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI) versions were read from the scan (VERIFIED)
  but their compatibility with each hop version was not individually checked against AWS's add-on
  compatibility matrix (ASSUMED they need to move in step with each control-plane hop, per general
  EKS policy).

## Repo findings (k8s-microservices-app, github)
4 removed Kubernetes APIs found in `charts/three-tier/templates/` (VERIFIED against the official
deprecation guide). 3 were patched in the accompanying pull request (apiVersion only, no other
changes); 1 (PodSecurityPolicy) has no replacement API and needs manual migration.
Owners to warn: unknown - no CODEOWNERS file was found in this repo.

## Support status
| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.32 (current) | EXTENDED | 2026-03-23 | 2027-03-23 |
| 1.37 (target) | STANDARD | 2027-12-01 | 2028-12-01 |

Urgency: CRITICAL - standard support for 1.32 already ended (2026-03-23); the cluster is currently
running on paid extended support. Fees: UNKNOWN (no fetched official page stated a dollar figure).

## Top blockers
- PodSecurityPolicy (policy/v1beta1) in charts/three-tier/templates/podsecuritypolicy.yaml has no replacement API in 1.25+ - needs manual migration to Pod Security Admission / an external policy controller before the 1.25 hop
- EKS managed add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI) must be upgraded in step with control-plane hops; versions were not individually checked against each target hop
- IRSA / Pod Identity association was not in the cluster scan - confirm before upgrading nodes that rely on it

## Coverage gaps
- needs scan (read only): IRSA / EKS Pod Identity association details for service accounts
- CODEOWNERS not found in repo - owners for affected namespaces are unknown, not guessed

## Plan only
Nothing in the live cluster was changed by this agent. The only write made was the pull request
with the three apiVersion fixes described above.
