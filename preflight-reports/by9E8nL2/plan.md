# Kubernetes upgrade plan: 1.32 -> 1.37 (kube-pilot, EKS, prod-eks)

Plan only. Nothing was upgraded and no live resource was modified. Scan `by9E8nL2Quq4DPwzEcHj-Q`.

## Readiness
- Zone: **AMBER** — readiness 50 now, 80 after the fixes in the pull request (needs PR review and merge).
- Score caps applied: removed-API findings are capped at 45 points even though 4 distinct findings were found (60 raw); the coverage-gap category added 5 more.

## Control plane hops (one minor per hop)
| To | Status | Notes |
|---|---|---|
| 1.33 | OK | Merge the fix PR first. extensions/v1beta1, autoscaling/v2beta1 and batch/v1beta1 are already removed as of the current 1.32 control plane — they are not fixable "at a future hop", they are already broken today. |
| 1.34 | OK | — |
| 1.35 | OK | — |
| 1.36 | OK | — |
| 1.37 | OK | Final target. |

Release links (EKS): https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for every hop above (per-version EKS release notes live on this single page; not an invented per-hop URL).

## Node pool hops
Skew limit used: kubelet may lag the control plane by up to 3 minor versions (Kubernetes kubelet-to-control-plane version-skew policy). ASSUMED — not refetched this run, based on general policy knowledge, not verified against a fetched page this run.

| To | Notes |
|---|---|
| 1.34 | Upgrade node pool `general-20261115161132087800000008` after control plane reaches 1.34 (both nodes currently kubelet v1.32.13). |
| 1.37 | Final node pool upgrade to close the skew window with the control plane at 1.37. |

Node facts (VERIFIED from scan): 2 nodes, both kubelet v1.32.13-eks-9adbfea, containerd 2.3.7, Amazon Linux 2023, arm64, pool `general-20261115161132087800000008`, both Ready.

## Platform checks (EKS)
- IRSA / Pod Identity: ASSUMED only — the cluster scan did not capture ServiceAccount IAM annotations, so this prerequisite could not be verified. Coverage gap recorded.
- Add-on versions (VERIFIED from scan, compatibility with 1.37 not fetched — ASSUMED current): aws-load-balancer-controller v2.8.1, coredns v1.11.4-eksbuild.104, aws-ebs-csi-driver v1.68.0, amazon-k8s-cni v1.22.4-eksbuild.14, kube-proxy v1.32.13-eksbuild.72. No incompatibility evidence found against these images; recommend checking the EKS add-on compatibility matrix at each hop before upgrading (not fetched here per instructions against fetching large release-note pages).
- IaC note (VERIFIED from repo, not scored): `infra/eks/variables.tf` has `cluster_version` default `"1.34"`, while the live cluster (`cluster_version.json`) reports `v1.32.13-eks-91f89a9`. Terraform state and the live cluster have drifted; reconcile before using Terraform to drive any future hop.

## Repo findings and fixes (VERIFIED from repo scan)
Repo: `k8s-microservices-app` (github). 4 distinct removed-API usages found, all already removed as of Kubernetes 1.22-1.25, i.e. already incompatible with the current 1.32 cluster, not just a future hop:

| File | apiVersion found | Removed in | Replacement | Fixed in this PR |
|---|---|---|---|---|
| charts/three-tier/templates/admin-ingress.yaml | extensions/v1beta1 (Ingress) | 1.22 | networking.k8s.io/v1 | Yes |
| charts/three-tier/templates/backend-hpa.yaml | autoscaling/v2beta1 (HPA) | 1.25 | autoscaling/v2 | Yes |
| charts/three-tier/templates/mysql-backup-cronjob.yaml | batch/v1beta1 (CronJob) | 1.25 | batch/v1 | Yes |
| charts/three-tier/templates/podsecuritypolicy.yaml | policy/v1beta1 (PodSecurityPolicy) | 1.25 | none (kind removed, no 1:1 replacement) | No — needs human review |

Owners to warn: unknown. No CODEOWNERS file was found in the cloned repo (checked CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS); do not guess owners.

Namespaces touched by this app repo (from the generated app-repo map): argocd, demo, default, cert-manager, ingress-nginx, reporting, harness-preflight.

## Support status (endoflife.date, product amazon-eks)
Used fields: `eol` as standard-support end, `extendedSupport` as extended-support end.

| Version | Status | Standard end | Extended end |
|---|---|---|---|
| 1.32 (current) | EXTENDED | 2026-03-23 | 2027-03-23 |
| 1.37 (target) | STANDARD | 2027-12-01 | 2028-12-01 |

Urgency: **CRITICAL** — standard support for 1.32 already ended on 2026-03-23 (today is 2026-11-16); the cluster is running in the paid extended-support window. Fees: UNKNOWN — no official AWS pricing page was fetched this run, so the extended-support hourly/monthly rate is not reported (never invented).

## Coverage gaps
- needs scan (read only): ServiceAccount IAM role annotations (IRSA/Pod Identity) for EKS platform prerequisite checks.

## Top blockers
1. policy/v1beta1 PodSecurityPolicy in charts/three-tier/templates/podsecuritypolicy.yaml has no replacement API and needs a manual migration to Pod Security Admission (or an equivalent policy engine) before relying on it.
2. IRSA/Pod Identity could not be verified from the scan (coverage gap) — confirm EKS platform prerequisites manually before the first hop.

## What happens next
A pull request on a new branch carries the 3 safe apiVersion fixes plus this plan and its HTML rendering under `preflight-reports/<scan id prefix>/`. It requires human review and merge; nothing here was applied to the live cluster.
