# Preflight Demo Estate (proposal for review)

> **Status: proposal.** This branch currently contains only this README.
> Please review the plan below. Once agreed, the implementation will be added to this same branch and PR.

## Why this change

The Preflight agent (Kubernetes upgrade readiness, **v1.32 → v1.36**) scans a cluster and its infra repo and produces an upgrade plan, a readiness score and a fix PR.

The current repo is a clean beginner app: plain YAML, only stable APIs (`v1`, `apps/v1`), no Helm, Kustomize, Terraform, add-ons or GitOps. Run against it, Preflight would find almost nothing, so the demo would show no hop risks and no PR worth reviewing.

This proposal turns the repo into a **realistic multi-environment estate** with upgrade problems that:

- are spread across **every layer** the agent scans (live cluster, Helm, Kustomize, Terraform, Argo CD, add-ons)
- break at **different hops**, so the hop track and the flagged `1.34!` hop are earned
- include issues that are **only visible live / in real time**, not just by grepping files
- include **ordering problems**, where the upgrade sequence matters
- are all **verified against official support tables** (sources at the bottom)

## Why 1.32 → 1.36 (and not 1.26 → 1.30)

- **1.32 is the oldest version that can still be created on all three managed clouds**: EKS (extended support until Mar 23, 2027), GKE (Extended channel until Feb 11, 2027), AKS (LTS on the Premium tier until Mar 2027). 1.26 can only run on kind / self-managed.
- It's where real teams are stuck: **1.32 is the last EKS version with Amazon Linux 2 AMIs**.
- The blockers in this range are current ones: retired add-ons, node OS changes, cgroup v2, containerd 2. Not just deprecated APIs.
- It keeps the same 4-hop shape as the architecture diagram.

## What stays unchanged

- `frontend/`, `backend/` app code
- `manifests/` and the root `README.md` beginner runbook (`kubectl apply -f manifests/` still works on Minikube)

## Proposed layout

```
PREFLIGHT_AGENT_README.md         this file (the root README.md stays as the beginner runbook)

charts/three-tier/                Helm chart of the existing app
  Chart.yaml                      kubeVersion constraint (see F01)
  values.yaml
  values-onprem.yaml              live demo cluster
  values-prod-eks.yaml
  values-staging-gke.yaml
  values-dev-aks.yaml
  templates/                      deployments, services, configmap, secret, SA, PDB, ingress

platform/                         cluster-level resources (Kustomize)
  base/                           FlowSchema + PriorityLevelConfiguration, legacy Endpoints client CronJob
  overlays/onprem|prod-eks|staging-gke|dev-aks
  argocd/                         Argo CD install pinned to v2.14.0

argocd/<env>/apps.yaml            Applications per env: app chart, platform overlay,
                                  ingress-nginx, cert-manager

infra/                            Terraform per environment (scanned, not applied)
  eks/  gke/  aks/
  onprem/kind-config.yaml         kind cluster pinned to kindest/node:v1.32.0 (by digest)

PREFLIGHT_AGENT_README.md         this file (root README.md stays as the beginner runbook)

preflight/
  EXPECTED_FINDINGS.md            answer key for testing the agent's output
  onprem/bootstrap.sh             builds the live 1.32 cluster for the demo
```

Environment names match the pipeline input set: `prod-eks`, `staging-gke`, `dev-aks`, plus `onprem` for the self-managed connector (kind is the live stand-in).

## Planted findings

Severity: **Blocker** = stops a hop or is already failing, **High** = breaks workloads or leaves a security gap, **Advisory** = platform or cost note.

| ID | Env | Source | What is planted | Breaks at | Severity | Fix in agent PR? |
|----|-----|--------|-----------------|-----------|----------|------------------|
| F01 | all | Helm | Chart `kubeVersion: ">=1.28.0-0 <1.34.0-0"` | **1.34** (Helm and Argo CD refuse to render) | Blocker | Yes: widen after confirming templates use GA APIs |
| F02 | all | Kustomize | `FlowSchema` + `PriorityLevelConfiguration` on `flowcontrol.apiserver.k8s.io/v1beta3` | **Already broken**: removed in 1.32. Visible live as a failing Argo CD sync | Blocker | Yes: bump to `v1` |
| F03 | onprem (live) | Live cluster | Nodes on `kindest/node:v1.32.0` (built by kind v0.26.0) run **containerd 1.7** | **1.36** removes containerd 1.x support | Blocker | Yes: pin a node image built with containerd 2 (kind v0.27.0+). **Seen in real time** in `node.status.nodeInfo.containerRuntimeVersion` |
| F04 | all | Argo CD / Helm | cert-manager **v1.16.x** (supported on 1.25 to 1.32) | **1.33** | Blocker | Yes, **two-step**: 1.20 (1.32 to 1.35) now, then 1.21 (1.33 to 1.36) before 1.36 |
| F05 | all | Kustomize | Argo CD **v2.14.0** (tested 1.28 to 1.31) | Already outside the tested range | Blocker (ordering) | No, manual and **two-step**: no single Argo CD release is tested on both 1.32 and 1.36. Upgrade to **3.4** (tested 1.32 to 1.35), then **3.5** (tested 1.33 to 1.36). Also crosses the v2 → v3 major upgrade |
| F06 | all | Argo CD / Helm | ingress-nginx chart **4.11.x** / controller **v1.11.x** | **Retired March 2026**: no more security fixes. v1.11 support table also ends at 1.30 | High | No: migrate to Gateway API or another controller (none are drop-in) |
| F07 | onprem (live) | Live cluster | CronJob "legacy report client" that lists `Endpoints` every 5 min | `Endpoints` deprecated in **1.33** (warning, not removed) | Advisory | No: owner moves to EndpointSlices. **Seen in real time** via `apiserver_requested_deprecated_apis` once the control plane is on 1.33 |
| F08 | onprem (live) | Helm values | MySQL single replica + PDB `minAvailable: 1` | Every **node roll**: drain blocks (live: `disruptionsAllowed: 0`) | High | Yes (values), needs review |
| F09 | onprem (live) | Helm values | MySQL on `emptyDir` | Every **node roll**: data loss | High | Yes: enable persistence |
| F10 | prod-eks | Terraform | Managed node group `ami_type = "AL2_x86_64"` | **1.33**: no EKS AL2 AMIs from 1.33. AL2 AMIs unpatched since Nov 26, 2025 | Blocker | Yes: AL2023. Bootstrap / user data must be reviewed |
| F11 | prod-eks | Terraform | `cluster_version = "1.32"`, add-ons (coredns, kube-proxy, vpc-cni) pinned to 1.32-era builds | Every hop | High | Yes: per-hop versions from `aws eks describe-addon-versions` |
| F12 | prod-eks | Terraform | 1.32 in **EKS extended support** since Mar 23, 2026 | Cost | Advisory | No: shows in the cost section |
| F13 | prod-eks | Helm values | IRSA role annotation on the service account | n/a | Advisory | No: EKS platform check suggests Pod Identity |
| F14 | staging-gke | Terraform | Node pool `cgroup_mode = "CGROUP_MODE_V1"` | **1.35+ kubelet**: fails to start on cgroup v1 by default | Blocker | Yes: `CGROUP_MODE_V2`. Flag workloads with cgroup v1 assumptions (old JVMs, monitoring agents) |
| F15 | staging-gke | Terraform | 1.32 only available on the **Extended channel** | Cost | Advisory | No |
| F16 | dev-aks | Terraform | 1.32 only via **LTS** (`sku_tier = "Premium"`, `support_plan = "AKSLongTermSupport"`), `node_os_channel_upgrade = "None"` | Cost; node images never patched | Advisory | No: AKS note that the node image upgrade is a separate operation |

## Expected upgrade plan (what a correct agent output looks like)

**Before the first hop (still on 1.32):** fix the already-broken F02, upgrade Argo CD to 3.4 (F05 step 1), plan the ingress-nginx migration (F06), and handle F08 / F09 before any node roll.

| Control plane hop | Must be done before this hop |
|---|---|
| 1.32 → 1.33 | cert-manager on 1.20 (F04 step 1). EKS node groups on AL2023 (F10). Endpoints warnings start (F07) |
| 1.33 → **1.34 !** | Chart `kubeVersion` widened (F01) |
| 1.34 → 1.35 | Nothing new for the control plane |
| 1.35 → 1.36 | Argo CD on 3.5 (F05 step 2), cert-manager on 1.21 (F04 step 2) |

**Node pool track:** 1.32 → 1.34 → 1.36 (the kubelet may lag the API server by up to 3 minors).
- The **first roll (1.34)** is blocked on EKS by F10, and on every env by F08 / F09 until they are handled.
- cgroup v1 (F14) and containerd 1.x (F03) are **kubelet-side**, so they hit at the **1.36 roll**, not at a control plane hop. This is the kind of detail a version-by-version checklist misses.

## Readiness score (proposal)

The scoring method is still open in the architecture. Suggested rule: **start at 100, subtract 8 per Blocker, 5 per High, 2 per Advisory.** Findings that only appear after a hop (F07) are not counted in the initial score.

For the live `onprem` environment:

| | Open findings | Score |
|---|---|---|
| **Before** | Blockers F01, F02, F03, F04, F05 (−40), High F06, F08, F09 (−15) | **45** (below the 80 threshold) |
| **After the fix PR** | F01, F02, F03, F04 step 1, F08, F09 fixed. F05 (Argo CD v3) and F06 (ingress-nginx migration) stay manual (−13) | **87** (Ready with conditions) |

## Live vs scanned

- **onprem** is the **live** cluster: kind on the delegate VM, created with **kind v0.26.0** and pinned by digest to `kindest/node:v1.32.0`. Live findings: F02 (failing sync), F03, F04, F05, F06, F07, F08, F09.
- **EKS / GKE / AKS** can be created on 1.32 today, but that costs extended support / LTS fees. Suggestion: scan them from Terraform and manifests, and only create a cloud cluster if the demo needs it.
- kind can't upgrade a cluster in place. That's fine for **readiness**; executing hops on a self-managed cluster would use kubeadm.



## Sources (checked 2026-10-19)

- Kubernetes deprecated API migration guide: kubernetes.io/docs/reference/using-api/deprecation-guide
- EKS Kubernetes version lifecycle and AL2 AMI deprecation FAQ: docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html, eks-ami-deprecation-faqs
- AKS supported Kubernetes versions and LTS: learn.microsoft.com/azure/aks/supported-kubernetes-versions
- GKE release schedule: docs.cloud.google.com/kubernetes-engine/docs/release-schedule
- Ingress NGINX retirement: kubernetes.io/blog/2025/11/11/ingress-nginx-retirement, kubernetes.io/blog/2026/01/29/ingress-nginx-statement
- cgroup v2 shift and containerd 1.x support ending in 1.36: kubernetes.io/blog/2026/10/06/kubernetes-cgroups-v2-shift, kubernetes.io/blog/2025/11/26/kubernetes-v1-35-sneak-peek
- Argo CD tested Kubernetes versions: `docs/operator-manual/tested-kubernetes-versions.md` at v2.14.0, v3.2.0, v3.5.5
- cert-manager supported releases: cert-manager.io/docs/releases
- ingress-nginx support table: repo `README.md` (main)
- kind release notes v0.26.0 (`kindest/node:v1.32.0`, containerd 1.x) and v0.27.0 (moves to containerd 2.x)
