# Kubernetes upgrade plan: 1.32 -> 1.35 (kube-pilot / prod-eks / EKS)

Readiness: **AMBER** -- initial score 36, projected 81 after the PR fixes in this run.
Scan: gVNiB8o6T0uG7ltSzvr0wQ

## Cluster facts (VERIFIED, from the read-only scan)
- Control plane: v1.32.13-eks-91f89a9
- Nodes: 2 nodes, kubelet v1.32.13-eks-9adbfea, containerd 2.3.7, Amazon Linux 2023, arch arm64, pool `general-...`, both Ready. No skew today (CP and kubelet both 1.32).
- Live deprecated-API usage: none detected (`deprecated_apis.json` empty).
- Namespaces: default, demo, harness-delegate-ng, harness-preflight, kube-node-lease, kube-public, kube-system.
- Add-ons (kube-system): aws-load-balancer-controller v2.8.1, coredns v1.11.4-eksbuild.104, ebs-csi-controller/node v1.68.0 (+csi sidecars), aws-node (VPC CNI) v1.22.4-eksbuild.14 + network-policy-agent v1.4.0.
- CRDs: AWS VPC/ELB custom resources only (`*.k8s.aws`, `*.amazonaws.com`), all with a single served/stored version -- no core-API CRD risk found.

## Control plane hops (every minor)
| To | Status | Notes |
|---|---|---|
| 1.33 | FLAGGED | Repo has removed-API manifests (see Repo findings) that must be fixed/reviewed first. [Release info](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) |
| 1.34 | FLAGGED | kubelet skew becomes 2 (ASSUMED n-3 limit). Re-verify add-on compatibility before this hop (coverage gap). [Release info](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) |
| 1.35 | FLAGGED | kubelet skew reaches 3 (the assumed limit) -- roll node pools promptly after this hop. Target has standard support until 2027-03-27. [Release info](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) |

## Node pool hops (may lag within the version-skew limit)
Skew limit used: kubelet may be up to **3 minor versions** behind kube-apiserver (ASSUMED from the
kubernetes.io version-skew policy; not re-fetched this run -- coverage gap).
| To | Notes |
|---|---|
| 1.35 | One roll only: 1.32 -> 1.35, performed after the control plane reaches 1.35. Skew never exceeds 3 at any intermediate hop above, so no earlier node roll is required. |

## Platform checks (EKS) -- mostly ASSUMED, not verified via cloud API
- IRSA / Pod Identity: not directly observable from node/add-on facts collected; ASSUMED fine given healthy add-on pods, but not confirmed. Coverage gap.
- Add-on compatibility (CoreDNS, VPC CNI, EBS CSI, AWS LB Controller) with 1.33-1.35: ASSUMED these need re-validation at each hop per standard EKS practice; exact compatible versions not fetched this run. Coverage gap.
- Node OS/runtime (Amazon Linux 2023, containerd 2.3.7, arm64): VERIFIED from scan, no known issue for 1.35.

## Repo findings (VERIFIED from grep + deprecation map; repo: k8s-microservices-app)
| File | apiVersion found | Removed in | Replacement | Status |
|---|---|---|---|---|
| charts/three-tier/templates/admin-ingress.yaml | extensions/v1beta1 (Ingress) | 1.22 | networking.k8s.io/v1 | **Fixed in this PR** |
| charts/three-tier/templates/backend-hpa.yaml | autoscaling/v2beta1 (HPA) | 1.25 | autoscaling/v2 | **Fixed in this PR** |
| charts/three-tier/templates/mysql-backup-cronjob.yaml | batch/v1beta1 (CronJob) | 1.25 | batch/v1 | **Fixed in this PR** |
| charts/three-tier/templates/podsecuritypolicy.yaml | policy/v1beta1 (PodSecurityPolicy) | 1.25 | none (PSP has no direct replacement) | **Needs human review** -- migrate to Pod Security Admission / namespace labels |

All four of these are already incompatible with the *current* cluster version (1.32), not just the
target -- they would already fail to apply today. This was added to the chart in the most recent repo
commit (`chart: add backend autoscaling, nightly MySQL backup, admin ingress and pod security policy
for prod-eks`).

Owners to warn: **unknown** -- no CODEOWNERS file was found in the cloned repo (checked CODEOWNERS,
.github/CODEOWNERS, docs/CODEOWNERS). Namespaces referenced in manifests: 7 found by the generated
app-repo map, all attributed to repo `k8s-microservices-app`.

## Support status (endoflife.date API, amazon-eks product)
| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.32 (current) | EXTENDED | 2026-03-23 (passed) | 2027-03-23 |
| 1.35 (target) | STANDARD | 2027-03-27 | 2028-03-27 |

Urgency: **CRITICAL** -- standard support for 1.32 already ended (2026-03-23); the cluster is only
covered by paid extended support until 2027-03-23. Fees: UNKNOWN (not stated on a fetched official
page this run).

## Score
- initial = 36 (100 minus: removed APIs in repo, capped 45; add-on upgrade ordering, 4; coverage gaps, capped 15)
- projected = 81 (initial + 45 for the 3 removed-API findings fixed and validated in this PR)
- zone = AMBER (projected >= 60: needs this PR reviewed and merged, plus manual follow-up on the PSP finding and the coverage gaps below)

## Coverage gaps
- needs scan (read only): EKS platform prerequisites (IRSA/Pod Identity role trust, add-on compatibility matrix)
- kubelet-to-control-plane version-skew limit (n-3) assumed from kubernetes.io policy, not re-fetched this run
- EKS add-on compatibility with 1.33-1.35 not verified against AWS EKS docs this run
- app-repo map owners unknown: no CODEOWNERS file in the cloned repo

## Top blockers
1. PodSecurityPolicy manifest uses a removed API with no replacement -- needs manual migration, already broken on the current 1.32 cluster.
2. EKS add-on compatibility with 1.33-1.35 not verified.
3. Platform prerequisites (IRSA/Pod Identity) not verified.

Plan only. Nothing in the live cluster was changed; the only write made was the PR described above.
