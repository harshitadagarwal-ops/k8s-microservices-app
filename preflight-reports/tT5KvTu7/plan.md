# Kubernetes upgrade plan: 1.32 -> 1.37 (kube-pilot, prod-eks, EKS)

Scan: tT5KvTu7RkmL9PNt5x28AA. Plan only -- nothing was upgraded or applied to any cluster.

## Readiness

- Zone: **AMBER**
- Score: 25 now, 70 projected after the 3 fixes in the accompanying pull request
- EKS extended support (kube-pilot requires it: standard support for 1.32 ended 2026-03-23, extended
  support runs to 2027-03-23 -- VERIFIED from endoflife.date). Target 1.37 is in standard support until
  2027-12-01, extended to 2028-12-01 -- VERIFIED. Fees: UNKNOWN (not stated by a fetched official page).

## Control plane hops (one minor at a time)

| To | Status | Notes |
|---|---|---|
| 1.33 | FLAGGED | Blocked today by `charts/three-tier/Chart.yaml` kubeVersion cap (`<1.33.0-0`) -- VERIFIED. Also `infra/eks/variables.tf` `cluster_version` default is already `1.34`, which would skip this hop -- VERIFIED, must be set to `1.33` first. |
| 1.34 | OK | No findings tied to this hop. |
| 1.35 | OK | Node pool reaches the documented kubelet skew limit here (see below). |
| 1.36 | OK | No findings tied to this hop. |
| 1.37 (target) | OK | Final node roll closes skew to 0. |

Release notes: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for every hop.

## Node pool hops

Skew limit used: kubelet may be up to 3 minor versions behind kube-apiserver (Kubernetes version skew
policy) -- VERIFIED from kubernetes.io. Nodes are currently in sync with the control plane (both 1.32.13
-- VERIFIED from nodes.json/cluster_version.json).

| To | Notes |
|---|---|
| 1.35 | Roll here -- control plane will be 3 minors ahead of nodes still at 1.32, the documented maximum. |
| 1.37 | Final roll to match the target control plane, skew back to 0. |

## Findings (repo + live, VERIFIED unless marked ASSUMED)

Fixed in the pull request (apiVersion swap only where the deprecation map names a replacement, plus the
minimal structural change the new apiVersion requires):

- `charts/three-tier/templates/admin-ingress.yaml`: `extensions/v1beta1` Ingress -> `networking.k8s.io/v1`
  (removed in Kubernetes 1.22). Already broken today wherever `ingress.admin.enabled` is true (it is, in
  `values-prod-eks.yaml`), since this apiVersion no longer exists on a 1.32 API server.
- `charts/three-tier/templates/backend-hpa.yaml`: `autoscaling/v2beta1` HPA -> `autoscaling/v2` (removed
  in Kubernetes 1.25). Enabled in `values-prod-eks.yaml` (`backend.autoscaling.enabled: true`).
- `charts/three-tier/templates/mysql-backup-cronjob.yaml`: `batch/v1beta1` CronJob -> `batch/v1` (removed
  in Kubernetes 1.25). Enabled in `values-prod-eks.yaml` (`mysql.backup.enabled: true`).

Needs human review (no replacement apiVersion, not patched):

- `charts/three-tier/templates/podsecuritypolicy.yaml`: `policy/v1beta1` PodSecurityPolicy (removed in
  Kubernetes 1.25, enabled in `values-prod-eks.yaml`). No drop-in apiVersion; migrate to Pod Security
  Admission labels or an external policy engine.

Platform prerequisites not met (ASSUMED consequence, VERIFIED source lines):

- `charts/three-tier/Chart.yaml:7` `kubeVersion: ">=1.28.0-0 <1.33.0-0"` blocks the 1.33 hop.
- `infra/eks/variables.tf:13` `cluster_version` default `1.34` would skip the 1.33 hop if applied as-is.

Add-ons that should be upgraded in step with the hops, not after (ASSUMED risk from version age, not
fetched from a compatibility matrix per instructions):

- Argo CD `v2.14.0` (`platform/argocd-install/kustomization.yaml:6`)
- ingress-nginx `4.11.3` (`gitops/prod-eks/apps.yaml`)
- cert-manager `v1.16.2` (`gitops/prod-eks/apps.yaml`)

Deprecated but not yet removed:

- `platform/service-inventory/base/cronjob.yaml` and `platform/base/legacy-endpoints-cronjob.yaml` call
  the core `v1` Endpoints REST endpoint directly; Endpoints is soft-deprecated in favour of
  `discovery.k8s.io/v1` EndpointSlice. Not removed yet, but the owner should migrate the consumer.

## Owners to warn

No CODEOWNERS file was found in this repo, so ownership of the affected namespaces (demo, kube-system
and friends) is **unknown** -- do not guess; have the platform team confirm before merging the PR.

## Platform checks (EKS)

- IRSA: `enable_irsa = true` and dedicated IAM roles exist for EBS CSI (`ebs-csi-v3`) and the load
  balancer controller -- VERIFIED from `infra/eks/eks.tf`. No EKS Pod Identity association found in the
  repo; IRSA is still in use -- ASSUMED fine for 1.37 (no deprecation of IRSA itself).
  - cluster_encryption_config and CloudWatch control-plane logging are disabled on purpose (account IAM
    guardrail) -- VERIFIED from a comment in `infra/eks/eks.tf`; not an upgrade blocker, but a standing
    observability/security gap worth flagging to the platform team.
- Node AMI: `AL2023_ARM_64_STANDARD` (Graviton, Amazon Linux 2023) -- VERIFIED from `infra/eks/eks.tf`
  and matches the live node OS image (`Amazon Linux 2023...`) -- already the current-generation AMI
  type, no migration needed.
- Add-ons `coredns`, `kube-proxy`, `vpc-cni`, `aws-ebs-csi-driver` are managed EKS add-ons with no pinned
  version in terraform (`cluster_addons = {}` per add-on) -- ASSUMED AWS keeps these compatible across
  the hop path since they are first-party managed add-ons, not independently verified here.

## Coverage gaps

- needs scan (read only): Argo CD Application sync/health status for three-tier, flowcontrol,
  ingress-nginx, cert-manager and argocd-install -- would confirm whether the removed-API templates
  above are already failing to sync on the live 1.32 control plane, versus merely latent in the repo.

## Hard rule reminder

This run never upgraded, modified, or scaled any live resource, and never read a secret. The only
GitHub write made was a new branch and a pull request targeting the branch this run was cloned from.
