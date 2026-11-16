# Kubernetes upgrade plan: 1.32 -> 1.37 (EKS, prod-eks, cluster kube-pilot)

Scan: d9FzY9hrRkmQ1ITA4JoUkQ. Plan only — nothing in this run upgraded, modified, or restarted any
live resource. The only write made was the pull request described in section "Pull request" below.

## Readiness score
- Zone: **AMBER** (needs PR review and merge before proceeding)
- Initial: 55 / 100 — Projected after this PR's fixes: 85 / 100
- Deductions (removed-API-in-use category capped at 45 points):
  1. extensions/v1beta1 Ingress in use, removed in 1.22 — 15 pts — **fixed** (VERIFIED: repo scan, map lookup)
  2. autoscaling/v2beta1 HorizontalPodAutoscaler in use, removed in 1.25 — 15 pts — **fixed** (VERIFIED)
  3. batch/v1beta1 CronJob in use, removed in 1.25 — 15 pts — **fixed** (VERIFIED)
  4. policy/v1beta1 PodSecurityPolicy in use, removed in 1.25, no replacement apiVersion — 15 pts — **unfixed, needs human review** (VERIFIED finding, ASSUMED remediation path)

The live cluster scan (`deprecated_apis.json`) reported no deprecated API server requests, so these
four findings are repo-only risk today (VERIFIED: the templates are not currently applied/serving
live traffic against the removed APIs) but will hard-fail the first `helm upgrade`/`kubectl apply`
against any control-plane version from 1.25 onward if deployed as-is.

## Control plane hops (every minor)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.33 | FLAGGED | Repo has removed-API manifests (fixed 3/4 in this PR); merge the PR before any apply. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.34 | OK | No cluster-level blocker in the scanned facts (ASSUMED: add-on/CRD compatibility at this version not independently verified — see coverage notes). | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.35 | OK | Same as above. Node pool hop recommended here (see below). | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.36 | OK | Same as above. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | Target version. Final node pool hop to converge. | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops (lag within version skew)
Skew limit used: kubelet may be up to 3 minor versions older than kube-apiserver (documented
Kubernetes version-skew policy). Current nodes are at 1.32.13 (VERIFIED: nodes.json), matching the
1.32.13 control plane (VERIFIED: cluster_version.json) — no skew violation today.

| To | Notes |
|---|---|
| 1.35 | Node pool upgraded here so it never falls more than 3 minors behind the control plane as it advances to 1.36. |
| 1.37 | Final node pool hop, converges nodes with the target control plane version. |

## Platform checks (EKS) — ASSUMED unless marked VERIFIED
- IRSA / Pod Identity: not independently checked (no cloud API access permitted); node labels and
  `aws-node` DaemonSet image (`amazon-k8s-cni:v1.22.4-eksbuild.14`, VERIFIED: addons.json) suggest IRSA
  is configured, but role bindings were not read. ASSUMED adequate; recommend a human confirm IRSA/Pod
  Identity role trust policies before the 1.33 hop.
- Add-on versions observed (VERIFIED: addons.json): aws-load-balancer-controller v2.8.1, coredns
  v1.11.4-eksbuild, ebs-csi-driver v1.68.0 + sidecars, aws-node (VPC CNI) v1.22.4-eksbuild.14,
  kube-proxy v1.32.13-eksbuild.72. Compatibility of these exact builds with 1.33-1.37 was not fetched
  (release notes are out of scope for this run) — ASSUMED compatible pending a human check against the
  EKS add-on version matrix at each hop.
- Node OS: Amazon Linux 2023 (VERIFIED: nodes.json) — current generation, no known blocker.
- CRDs observed (VERIFIED: crds.json): AWS VPC/ELB CRDs at v1alpha1/v1beta1 (own group, not a core
  Kubernetes deprecation) — these are vendor CRDs and not subject to the Kubernetes deprecation guide;
  no action needed from this scan.

## Owners to warn
The repo has no CODEOWNERS file (checked CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS) — owners
are **unknown** for every namespace in the generated app-repo map (argocd, demo, default, cert-manager,
ingress-nginx, reporting, harness-preflight). Recommend adding CODEOWNERS so future runs can route
findings to the right team.

## Pull request
This run fixed and validated 3 of the 4 removed-API findings in `charts/three-tier/templates/` and
opened a pull request with those changes plus this plan (see the PR link in output.json/final answer).
The PodSecurityPolicy finding was left unpatched because the deprecation guide names no replacement
apiVersion — it needs a human decision (Pod Security Admission labels, or an external policy
controller) and is listed as a top blocker.

## Coverage gaps
None. All 6 cluster fact files were collected with status "ok", the Kubernetes deprecation guide
fetched successfully (37 entries), the app-repo map was derived from the cloned repo, and the
endoflife.date lookups for both versions succeeded.

## Support status
- Current (1.32): EXTENDED support (standard support ended 2026-03-23; extended support runs through
  2027-03-23, per endoflife.date `eol`/`extendedSupport` fields). Fees: UNKNOWN (not fetched from an
  official pricing page).
- Target (1.37): STANDARD support (standard support ends 2027-12-01; extended through 2028-12-01).
  Fees: UNKNOWN.
- Urgency: **MEDIUM** (current version's active support window, extended support, ends in ~127 days).

## Hard rules honored
Plan only. No upgrade, scale, restart, cordon, drain, sync, exec, port-forward, or RBAC/secret change
was requested or performed. The only write was the pull request branch created in section 10.
