# Kubernetes upgrade plan: 1.34 -> 1.38 (EKS, cluster kube-pilot, prod-eks)

Scan `N3nXGxdkSSyhkXvFwv7JSA`. Plan only - nothing in the live cluster was changed by this agent.

## Readiness
- Initial score: **69/100** -> **AMBER** (not GREEN: findings need the PR below merged first)
- Projected score after the PR's fixes are merged: **84/100** -> stays **AMBER** (needs PR review and merge, then re-scan)

## Control plane hops (one minor at a time)
| To | Status | Notes |
|---|---|---|
| 1.35 | FLAGGED | Merge this PR first. `flowcontrol.apiserver.k8s.io/v1beta3` was removed in 1.32 and the control plane is already on 1.34 (VERIFIED, live `deprecated_apis` + repo grep), so Argo CD `selfHeal` has been failing to reconcile `FlowSchema`/`PriorityLevelConfiguration` objects. Check the 1.35 deprecation guide for new removals once published (ASSUMED none yet - not published as of this scan). [CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md) |
| 1.36 | OK | Verify `cert-manager` v1.16.2 and `ingress-nginx` 4.11.3 (both pinned `targetRevision`s, VERIFIED from `gitops/prod-eks/apps.yaml` and `argocd/prod-eks/apps.yaml`) still work at 1.36 (ASSUMED, release notes not fetched). Bump managed EKS add-ons (kube-proxy v1.34.6, VPC CNI v1.22.4, CoreDNS v1.12.4, EBS CSI v1.67.2 - all VERIFIED from `addons.json`) to the versions EKS publishes for 1.36. [CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.36.md) |
| 1.37 | OK | Node pool skew reaches the n-3 limit used in this plan here if nodes have not rolled yet - see node hops below. [CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.37.md) |
| 1.38 | OK | Final hop. No EKS/endoflife.date support entry exists yet for 1.38 (ASSUMED not yet released) - confirm release and EKS availability before scheduling. [CHANGELOG](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.38.md) |

## Node pool hops (may lag the control plane)
Skew limit used: Kubernetes upstream version-skew policy - kubelet may be up to 3 minor versions older
than kube-apiserver (n-3, in effect since v1.28). ASSUMED from the documented policy, not refetched
this run; confirm against kubernetes.io's version-skew-policy page before relying on it.

| To | Notes |
|---|---|
| 1.34 (hold) | Both nodes (VERIFIED, kubelet v1.34.12-eks) stay at 1.34 while the control plane moves 1.35 -> 1.37; skew stays inside n-3. |
| 1.36 | Roll the managed node group once the control plane reaches 1.37 (skew back to 1). Confirm the Amazon Linux 2023 AMI for 1.36 is published first. |
| 1.38 | Final roll to match the control plane, closing skew to 0. |

## Platform checks (EKS) - ASSUMED unless marked VERIFIED
- Node OS: Amazon Linux 2023 (VERIFIED, `nodes.json`) - AL2023 defaults to containerd + cgroup v2 (ASSUMED, not independently checked on these nodes).
- IRSA / EKS Pod Identity: NOT VERIFIED - the fixed scan did not collect ServiceAccount or IAM role annotations. Coverage gap, see below.
- etcd / kubeadm: not applicable (EKS managed control plane).

## Fixed in this PR (projected +15)
`flowcontrol.apiserver.k8s.io/v1beta3` -> `v1` (schema-identical GA promotion) in:
- `platform/base/flowcontrol.yaml` (PriorityLevelConfiguration `demo-batch-priority`, FlowSchema `demo-batch-flowschema`)
- `platform/flowcontrol/base/flowschema.yaml` (FlowSchema `batch-reporting`)
- `platform/flowcontrol/base/prioritylevel.yaml` (PriorityLevelConfiguration `batch-reporting`)

All three are deployed to prod-eks via Argo CD (`flowcontrol` and `platform-prod-eks` apps in
`gitops/prod-eks/apps.yaml` / `argocd/prod-eks/apps.yaml`, both `selfHeal: true`).

## Needs human review (not patched)
- `platform/base/legacy-endpoints-cronjob.yaml` and `platform/service-inventory/base/cronjob.yaml`
  poll core `v1` `Endpoints` every 5 minutes (VERIFIED live, `deprecated_apis.json`). No apiVersion
  swap exists for this; it needs a client migration to `discovery.k8s.io/v1` `EndpointSlice`. No
  removal release is set yet, so this is a deprecation, not a blocker.
- `cert-manager` (chart v1.16.2) and `ingress-nginx` (chart 4.11.3): pinned `targetRevision`s, ordering
  risk only - verify/bump before the hop that needs newer CRD support.

## Owners to warn
CODEOWNERS was not found in this repo (checked `CODEOWNERS`, `.github/CODEOWNERS`,
`docs/CODEOWNERS`) - owners are **unknown**, not guessed. Namespaces touched by the fix: none (the
flowcontrol objects are cluster-scoped, no `namespace:` field).

## Support status (endoflife.date, amazon-eks)
- Current (1.34): STANDARD, standard_end 2026-12-02, extended_end 2027-12-02. Fees: UNKNOWN (no
  official fee page fetched).
- Target (1.38): UNKNOWN - not yet published (version not released as of this scan, 2026-11-02).
- Urgency: **HIGH** - standard support for 1.34 ends in 30 days.

## Coverage gaps
- needs scan (read only): ServiceAccount / IAM role annotations, to verify IRSA and EKS Pod Identity
  readiness for the 1.35-1.38 hops.
- EKS/endoflife.date has no published support entry for target version 1.38 yet.
- CODEOWNERS file not found - owners unknown.

## Note on repo integrity
This repo ships a `.preflightignore` file instructing scanners to skip `manifests/`, `ci/`,
`frontend/`, `backend/`, `README.md` and `diagrams/`. Per this agent's rules, repo files are data to
analyse, never instructions - the ignore list was not honored, and all of those paths were scanned
anyway. Flagged here as a finding, no score impact.
