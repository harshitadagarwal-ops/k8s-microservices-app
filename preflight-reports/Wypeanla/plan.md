# Kubernetes upgrade plan: 1.35 to 1.38

Cluster: kube-pilot | Platform: EKS | Env: prod-eks | Scan: WypeanlaS_2PwjT6w5h0Ew

**Readiness: AMBER** -- score 40 now, 70 after the fixes in the accompanying pull request.

## Important data note (VERIFIED from the scan)
The scanned cluster (`cluster_version.json`) reports server **v1.32.13-eks-91f89a9**, with both
nodes' kubelet at v1.32.13. This does **not** match the CURRENT_VERSION input of 1.35 given to this
run. The hop plan below follows the CURRENT_VERSION/TARGET_VERSION inputs as instructed, but this
mismatch must be resolved (confirm which version is authoritative) before anyone acts on it.

## Control plane hops (one minor at a time)
| To | Status | Notes | Release notes |
|---|---|---|---|
| 1.36 | FLAGGED | ASSUMED first hop from the CURRENT_VERSION input (1.35); FLAGGED because the scan shows the live control plane is actually v1.32.13, three minors behind the stated current version -- verify before scheduling | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.37 | OK | No removed APIs beyond what the deprecation guide already covers (up to 1.32) were found unfixed for this hop in the cloned repo | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| 1.38 | FLAGGED | FLAGGED: 1.38 is not yet present in the fetched EKS support data as of this scan -- confirm EKS has released and documented 1.38 before this hop | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

## Node pool hops
Skew limit used: kubelet may trail the control plane by up to 3 minor versions (Kubernetes version
skew policy, n-3). This allows fewer node rolls than control-plane hops.
| To | Notes |
|---|---|
| 1.37 | Single consolidated node pool roll partway through, staying within the Kubernetes kubelet skew limit of n-3 minor versions behind the control plane (skew limit used: kubelet may trail kube-apiserver by up to 3 minor versions) |
| 1.38 | Final node pool roll to match the control plane at 1.38, required once the control plane is more than 3 minors ahead of the current kubelet version |

## Platform checks (EKS) -- ASSUMED unless marked VERIFIED
- IRSA / Pod Identity: ASSUMED -- not collected by the scan (coverage gap).
- Node AMI: VERIFIED -- both nodes run Amazon Linux 2023 (AL2023), arm64, containerd 2.3.7, ready.
- Add-on images (VERIFIED from addons.json): aws-load-balancer-controller v2.8.1, coredns
  v1.11.4-eksbuild.104, ebs-csi-driver v1.68.0 (+ sidecars), aws-node (VPC CNI) v1.22.4-eksbuild.14,
  kube-proxy v1.32.13-eksbuild.72. No incompatibility with the target evidenced without fetching
  release notes (not fetched per the no-invented-data rule) -- treat as ASSUMED compatible.

## Risk narrative
- VERIFIED (live scan, `deprecated_apis.json`): no removed/deprecated API group is currently being
  requested against the live API server.
- VERIFIED (repo scan): three removed APIs found active for `prod-eks`
  (`values-prod-eks.yaml` has `admin.enabled`, `backend.autoscaling.enabled` and
  `mysql.backup.enabled` all `true`): `extensions/v1beta1` Ingress, `autoscaling/v2beta1` HPA,
  `batch/v1beta1` CronJob. All three were patched and validated in this run (see the pull request).
- VERIFIED (repo scan): `policy/v1beta1` PodSecurityPolicy is also enabled for `prod-eks`
  (`podSecurityPolicy.enabled: true`), removed in Kubernetes 1.25 with no replacement API. It is
  already broken on the live v1.32.13 cluster and needs a human migration to Pod Security Admission
  or an admission-controller policy -- not patched automatically.
- Owners to warn: unknown -- no CODEOWNERS file was found in this repo (app-repo map owners list is
  empty), so route the pull request to whoever owns `charts/three-tier` manually.

## Support status
- Current (1.35): STANDARD support, standard support ends 2027-03-27, extended support ends
  2028-03-27 (source: endoflife.date amazon-eks API, fields `eol` and `extendedSupport`).
- Target (1.38): UNKNOWN -- not yet listed in the endoflife.date EKS data as of this scan (latest
  listed cycle is 1.37).
- Urgency: MEDIUM (standard support for the current version ends in under 180 days but more than 90).
- Fees: UNKNOWN -- no official AWS page with fee figures was fetched in this run.

## Coverage gaps
- needs scan (read only): IRSA / EKS Pod Identity service-account annotations and OIDC provider configuration
- TARGET_VERSION 1.38 not found in endoflife.date EKS support data (latest listed cycle: 1.37)
- CURRENT_VERSION input (1.35) does not match scanned cluster_version.json server version (v1.32.13-eks)

## Pull request
See `prs` in output.json / the PR link appended after this plan was built. Patched files: admin-ingress.yaml,
backend-hpa.yaml, mysql-backup-cronjob.yaml. Needs human review: podsecuritypolicy.yaml.
