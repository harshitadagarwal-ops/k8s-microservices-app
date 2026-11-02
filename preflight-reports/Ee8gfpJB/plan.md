# Kubernetes upgrade readiness plan: 1.34 -> 1.38 (EKS, prod-eks, cluster kube-pilot, scan Ee8gfpJBQy-ZW5VcEek0mQ)

## Readiness
- initial score: 77 / 100 (zone AMBER before this PR merges)
- projected score: 92 / 100 (after the validated fix in this PR is merged)

## Control plane hops (one minor at a time)
| To | Status | Notes |
|----|--------|-------|
| 1.35 | FLAGGED | Widen Chart.yaml kubeVersion (currently excludes 1.34+, VERIFIED from charts/three-tier/Chart.yaml:7) and merge the flowcontrol.apiserver.k8s.io/v1 fix (VERIFIED, already broken since 1.32). ASSUMED: re-check cert-manager v1.16.2, ingress-nginx 4.11.3, Argo CD v2.14.0 pins against their own support windows (not fetched in this run). |
| 1.36 | OK | No further removed/deprecated APIs found in the repo scan or the official deprecation map at or before this release. |
| 1.37 | OK | Node pool may still be at 1.34 (within the 3-minor skew limit). |
| 1.38 | FLAGGED | Target. Node pool roll must land at >=1.35 by this point. |

Release reference (EKS): https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html

## Node pool track
Skew limit used: kubelet may lag kube-apiserver by up to 3 minor versions (https://kubernetes.io/releases/version-skew-policy/).
- Node pool "general" (2x AL2023 arm64, containerd 2.3.7, kubelet v1.34.12-eks, VERIFIED from facts/nodes.json) can stay at 1.34 while the control plane moves through 1.35-1.37.
- A single roll straight to 1.38 is sufficient; it may start once the control plane reaches 1.35 and must complete by the time the control plane reaches 1.38.
- ASSUMED/drift note: infra/eks/eks.tf declares `ami_type = "AL2023_x86_64_STANDARD"` (x86_64) but the live nodes report arch arm64 (facts/nodes.json) - this Terraform/live drift should be reconciled before any node AMI change, independent of the version upgrade.

## Platform checks (EKS) - derived from facts, most marked ASSUMED
- IRSA: VERIFIED configured and in use (infra/eks/eks.tf enable_irsa=true, ebs-csi-irsa OIDC role; charts/three-tier/values-prod-eks.yaml has eks.amazonaws.com/role-arn). ASSUMED: EKS Pod Identity is a newer alternative worth evaluating but IRSA remains supported through the target version; no action required for readiness.
- Add-ons observed live (facts/addons.json, VERIFIED): aws-load-balancer-controller v2.8.1, coredns v1.12.4-eksbuild.70, aws-ebs-csi-driver v1.67.2 (+ sidecars), aws-node (VPC CNI) v1.22.4-eksbuild.10, kube-proxy v1.34.6-eksbuild.62. ASSUMED: these were not checked against a per-hop EKS add-on compatibility matrix in this run (release notes were not fetched); re-verify each add-on's supported version range before each control-plane hop.
- CRDs (facts/crds.json, VERIFIED): all AWS VPC/ELB CRDs have a single stored version matching a served version; no stored/served mismatch found.

## Risk narrative
- VERIFIED (official Kubernetes deprecation guide): flowcontrol.apiserver.k8s.io/v1beta3 (FlowSchema, PriorityLevelConfiguration) was removed in 1.32, replaced by flowcontrol.apiserver.k8s.io/v1. Found in platform/base/flowcontrol.yaml, platform/flowcontrol/base/flowschema.yaml, platform/flowcontrol/base/prioritylevel.yaml. **Fixed and validated in this PR.**
- VERIFIED (live scan facts/deprecated_apis.json + repo platform/base/legacy-endpoints-cronjob.yaml): core/v1 Endpoints is still queried every 5 minutes by a CronJob/ClusterRole. Deprecated (warning only) since 1.33, not yet removed, and has no versioned apiVersion replacement (the recommended move is to the different discovery.k8s.io/v1 EndpointSlice resource) - **left for human review**, owner should migrate the client.
- VERIFIED (repo charts/three-tier/Chart.yaml:7): kubeVersion ">=1.28.0-0 <1.34.0-0" already excludes the current server version 1.34.11-eks and every target hop. **Left for human review** - not an apiVersion/deprecation-map swap, outside this agent's auto-fix scope.
- ASSUMED: cert-manager (argocd/gitops prod-eks apps.yaml, pinned v1.16.2), ingress-nginx (pinned chart 4.11.3 / controller v1.11.x) and Argo CD (platform/argocd/kustomization.yaml, pinned v2.14.0) are old pins found in the repo; their supported Kubernetes version windows were not fetched in this run (release notes are out of scope) - re-verify before hops 1.35+.

## Support status (endoflife.date API, amazon-eks, fetched 2026-11-02)
- current (1.34): status STANDARD, standard_end (field "eol") 2026-12-02, extended_end (field "extendedSupport") 2027-12-02. Today is 2026-11-02: standard support ends in 30 days.
- target (1.38): status UNKNOWN - no 1.38 cycle is published yet by endoflife.date for amazon-eks.
- fees: UNKNOWN (not stated on a fetched official page in this run).
- urgency: HIGH (current version's standard support ends within 90 days).

## Owners to warn
No CODEOWNERS file was found in the repository (checked CODEOWNERS, .github/CODEOWNERS, docs/CODEOWNERS), so owners are UNKNOWN for every namespace in the generated app-repo map (argocd, demo, default, cert-manager, ingress-nginx, reporting, and others derived from manifests). Do not guess owners.

## Coverage gaps
None. All six cluster fact files (cluster_version, nodes, deprecated_apis, addons, crds, namespaces) returned status ok, and both the deprecation map (fetched live from kubernetes.io, 37 entries) and the app-repo map (derived from the cloned repo's manifests; no CODEOWNERS present) were built successfully.
