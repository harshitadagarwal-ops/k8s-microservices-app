# Preflight Demo Estate

> **Status: implemented on this branch, for review.** The app, `manifests/` and the root runbook are unchanged. Run `ci/validate.sh` to check the estate.
> Grading a run: see [preflight/EXPECTED_FINDINGS.md](preflight/EXPECTED_FINDINGS.md) for the evidence location of every finding.

## Why this change

The Preflight agent (Kubernetes upgrade readiness, **v1.32 → v1.36**) scans a cluster and its infra repo and produces an upgrade plan, a readiness score and a fix PR.

The current repo is a clean beginner app: plain YAML, only stable APIs (`v1`, `apps/v1`), no Helm, Kustomize, Terraform, add-ons or GitOps. Run against it, Preflight would find almost nothing, so the demo would show no hop risks and no PR worth reviewing.

This proposal turns the repo into a **realistic multi-environment estate** with upgrade problems that:

- are spread across **every layer** the agent scans (live cluster, Helm, Kustomize, Terraform, Argo CD, add-ons)
- break at **different hops**, so the hop track and the flagged `1.34!` hop are earned
- include issues that are **only visible live / in real time**, not just by grepping files
- include **ordering problems**, where the upgrade sequence matters
- are **checked by CI**, not only described here (see [Validation](#validation))

## Why 1.32 → 1.36 (and not 1.26 → 1.30)

- **1.32 is the oldest version that can still be created on all three managed clouds**: EKS (extended support until Mar 23, 2027), GKE (Extended channel until Feb 11, 2027), AKS (LTS on the Premium tier until Mar 2027, see [open items](#open-items-to-verify-before-implementation)). 1.26 can only run on kind / self-managed.
- It's where real teams are stuck: **1.32 is the last EKS version with Amazon Linux 2 AMIs**.
- The blockers in this range are current ones: retired add-ons, node OS changes, cgroup v2, containerd 2. Not just deprecated APIs.
- It keeps the same 4-hop shape as the architecture diagram. The diagram's versions (1.26 → 1.30) and scores (58 → 91) are illustrative; this estate uses 1.32 → 1.36 and the scores below.

## What stays unchanged

- `frontend/`, `backend/` app code
- `manifests/` and the root `README.md` beginner runbook (`kubectl apply -f manifests/` still works on Minikube)
- The Helm chart is the **source of truth for the demo**. `manifests/` is kept only for the runbook and is excluded from the scan, so it doesn't produce duplicate findings.

## Proposed layout

```
PREFLIGHT_AGENT_README.md           this file (root README.md stays as the beginner runbook)
.preflightignore                    paths the agent must not read (answer key, runbook, app code)

charts/three-tier/                  Helm chart of the existing app
  Chart.yaml                        kubeVersion constraint (F01)
  values.yaml
  values-onprem.yaml                live demo cluster (F08, F09)
  values-prod-eks.yaml              IRSA annotation (F13)
  values-staging-gke.yaml
  values-dev-aks.yaml
  templates/                        deployments, services, configmap, secret, SA, PDB, ingress

platform/                           cluster-level resources (Kustomize), one Argo CD Application each
  flowcontrol/base + overlays/<env>           FlowSchema + PriorityLevelConfiguration (F02)
  service-inventory/base + overlays/onprem    Endpoints-listing CronJob + ClusterRole (F07)
  argocd-install/                             Argo CD install pinned to v2.14.0 (F05)

gitops/<env>/apps.yaml              Argo CD Applications per env: app chart, flowcontrol,
                                    service-inventory (onprem), ingress-nginx, cert-manager

infra/                              Terraform per environment (scanned, not applied)
  eks/  gke/  aks/                  providers and modules pinned, .terraform.lock.hcl committed

onprem/                             everything for the live self-managed stand-in
  kind-config.yaml                  kindest/node:v1.32.0 pinned by digest, fixed apiServerPort, audit log
  audit-policy.yaml                 logs Endpoints / EndpointSlice reads (F07 live evidence)
  bootstrap.sh                      kind cluster, image build + `kind load`, Argo CD, Applications
  delegate.md                       how to run the Docker delegate on the VM (outside kind)

ci/validate.sh                      proves each planted finding behaves as described

preflight/                          excluded from the scan via .preflightignore
  EXPECTED_FINDINGS.md              answer key for testing the agent's output
```

Environment names match the pipeline input set: `prod-eks`, `staging-gke`, `dev-aks`, plus `onprem` for the self-managed connector (kind is the live stand-in).

## Environments, connectors and scan mode

The architecture gives every environment a Kubernetes connector, a Git connector and a Delegate. Only `onprem` has a real cluster, so the cloud environments run in **repo-only** mode: step 1 skips the cluster scan, and any finding that would normally be confirmed live is reported as *"not verified live"*.

| Env (input set) | Kubernetes connector | Git connector | Delegate | Scan mode |
|---|---|---|---|---|
| `onprem-k8s-connector` | kind cluster on the VM | this repo | Docker delegate on the VM | live + repo |
| `prod-eks-connector` | none | this repo | same VM delegate | repo-only |
| `staging-gke-connector` | none | this repo | same VM delegate | repo-only |
| `dev-aks-connector` | none | this repo | same VM delegate | repo-only |

**The delegate runs outside the cluster under test.** It's a Docker delegate on the VM (`--network host`, with the kind kubeconfig mounted), not a pod inside kind. Rebuilding the kind cluster, which the F03 fix requires, would otherwise kill the agent's own delegate. kind is created with a fixed `apiServerPort` so the delegate's kubeconfig stays valid across rebuilds. The existing in-cluster `harness-delegate.yaml` is not used for this demo and is git-ignored because it contains a token.

## Keeping the answer key away from the agent

The agent scans the whole repo, and the LLM step would happily repeat an answer key if it could read one. So:

- `.preflightignore` lists `preflight/`, `ci/`, `PREFLIGHT_AGENT_README.md`, `README.md`, `CONTENT.md`, `manifests/`, `diagrams/`, `frontend/`, `backend/`. The agent must honour it in step 1.
- Planted files contain **no hints**: no `# planted`, no finding IDs, no "deprecated" comments. They should look like an ordinary, slightly neglected estate.
- `ci/validate.sh` fails if the agent's evidence for any finding cites an ignored path.
- `preflight/EXPECTED_FINDINGS.md` holds the grading key: the file and line each finding should be cited from, the live check command, and the expected PR change. The table below stays here for reviewers; both files are excluded from the scan.
- Directory and resource names are neutral too: the Endpoints client is called `service-inventory`, not "legacy-report-client".
- Stronger option if needed later: keep the answer key in a separate repo the agent's Git connector can't reach.

## Planted findings

**Break type** says what actually happens at the hop:

| Break type | Meaning |
|---|---|
| `removed` | API or feature is gone; apply / render / start fails |
| `refuses` | a tool or component refuses to run (version constraint, kubelet check) |
| `unsupported` | still works, but outside the vendor's tested / supported range |
| `retired` | project gets no more security fixes |
| `workload` | the upgrade operation itself (drain, node roll) breaks or loses data |
| `cost` / `platform` | billing or platform-operation note |

**Severity** follows from the break type: **Blocker** = `removed` / `refuses` at a hop the plan crosses. **High** = `unsupported`, `retired` or `workload`. **Advisory** = `cost` / `platform` or a warning-only deprecation.

| ID | Env | Source | What is planted | Breaks at | Break type | Severity | Fix in agent PR? |
|----|-----|--------|-----------------|-----------|------------|----------|------------------|
| F01 | all | Helm | Chart `kubeVersion: ">=1.28.0-0 <1.34.0-0"` | **1.34** (Helm and Argo CD refuse to render) | refuses | Blocker | Yes: widen after confirming templates use GA APIs |
| F02 | all | Kustomize | `FlowSchema` + `PriorityLevelConfiguration` on `flowcontrol.apiserver.k8s.io/v1beta3` | **Already broken**: removed in 1.32. Live as a failing sync of the `flowcontrol` Application | removed | Blocker | Yes: bump to `v1` |
| F03 | onprem (live) | Live cluster | Nodes on `kindest/node:v1.32.0` (built by kind v0.26.0) run **containerd 1.7** | **1.36 kubelet**: containerd 1.x no longer supported | refuses (verify) | Blocker | Yes, PR + manual rebuild (see below). **Seen in real time** in `node.status.nodeInfo.containerRuntimeVersion` |
| F04 | all | Argo CD / Helm | cert-manager **v1.16.x** (supported on 1.25 to 1.32) | **1.33** | unsupported | High (ordering) | Yes, **two-step**: 1.20 (1.32 to 1.35) now, then 1.21 (1.33 to 1.36) before CP 1.36 |
| F05 | all | Kustomize | Argo CD **v2.14.0** (tested 1.28 to 1.31) | Already outside the tested range (it runs, but untested) | unsupported | High (ordering) | No, manual and **two-step**: no single Argo CD release is tested on both 1.32 and 1.36. **3.4** (tested 1.32 to 1.35), then **3.5** (tested 1.33 to 1.36) before CP 1.36. Also crosses the v2 → v3 major upgrade |
| F06 | all | Argo CD / Helm | ingress-nginx chart **4.11.x** / controller **v1.11.x** | **Retired March 2026**: no more security fixes. v1.11 support table also ends at 1.30 | retired | High | No: migrate to Gateway API or another controller (none are drop-in) |
| F07 | onprem (live) | Kustomize + live | CronJob `service-inventory-report` that lists `Endpoints` every 5 min, with a ClusterRole granting `list endpoints` | `Endpoints` deprecated in **1.33** (warning only, not removed) | unsupported (warning) | Advisory | No: owner moves to EndpointSlices. See [F07 evidence](#f07-evidence) |
| F08 | onprem (live) | Helm values | MySQL single replica + PDB `minAvailable: 1` | Every **node roll**: drain blocks (live: `disruptionsAllowed: 0`) | workload | High | Yes, needs review: PDB becomes `maxUnavailable: 1`, which **accepts a short MySQL outage** per roll. Real HA (replication) is out of scope |
| F09 | onprem (live) | Helm values | MySQL on `emptyDir` | Every **node roll**: data loss | workload | High | Yes: enable persistence (PVC on kind's `standard` StorageClass) |
| F10 | prod-eks | Terraform | Managed node group `ami_type = "AL2_x86_64"` | **First node roll**: no EKS AL2 AMIs from 1.33. AL2 AMIs unpatched since Nov 26, 2025 | removed | Blocker | Yes: AL2023. Bootstrap / user data must be reviewed |
| F11 | prod-eks | Terraform | `cluster_version = "1.32"`, add-ons (coredns, kube-proxy, vpc-cni) pinned to 1.32-era builds | Every hop | unsupported | High | Yes: per-hop versions from `aws eks describe-addon-versions` |
| F12 | prod-eks | Terraform | 1.32 in **EKS extended support** since Mar 23, 2026 | n/a | cost | Advisory | No: shows in the cost section |
| F13 | prod-eks | Helm values | IRSA role annotation on the service account | n/a | platform | Advisory | No: EKS platform check suggests Pod Identity |
| F14 | staging-gke | Terraform | Node pool `linux_node_config.cgroup_mode = "CGROUP_MODE_V1"` | **1.35+ kubelet**: fails to start on cgroup v1 by default | refuses | Blocker | Yes: `CGROUP_MODE_V2`. Flag workloads with cgroup v1 assumptions (old JVMs, monitoring agents) |
| F15 | staging-gke | Terraform | 1.32 only available on the **Extended channel** | n/a | cost | Advisory | No |
| F16 | dev-aks | Terraform | 1.32 only via **LTS** (`sku_tier = "Premium"`, `support_plan = "AKSLongTermSupport"`), `node_os_upgrade_channel = "None"` (azurerm v4 name) | Node images never patched | cost / platform | Advisory | No: AKS note that the node image upgrade is a separate operation |

### F03: what the fix actually involves

A merged PR doesn't change a running kind cluster. The PR:

1. pins the kind CLI in `onprem/bootstrap.sh` to **v0.27.0 or later** (the first release whose node images use containerd 2), and
2. pins `onprem/kind-config.yaml` to the matching `kindest/node:v1.32.x` image **by digest from that release's notes** (still 1.32, so the readiness baseline doesn't move).

The cluster then has to be **recreated** (`bootstrap.sh --recreate`) as a manual step after merge. Until then F03 stays open live, even though the PR is merged. On a real self-managed cluster the same fix is a containerd 2 upgrade on each node during a drain.

### F07 evidence

The live cluster stays on 1.32 (kind can't upgrade in place), so the 1.33 deprecation warning never appears live. F07 is therefore found from evidence that exists **on 1.32**:

- **Static**: the CronJob's Role grants `list` on `endpoints`, and its container command calls the Endpoints API.
- **Live**: the CronJob's Jobs complete every 5 minutes, which shows it is still in use, not dead config.
- **Optional, real time**: `onprem/kind-config.yaml` enables an API server audit policy (via `kubeadmConfigPatches`) that logs `list endpoints` calls by the CronJob's ServiceAccount.

F07 lives in its own Application (`service-inventory`), separate from `flowcontrol`. If they shared one, F02's failing sync would stop Argo CD from applying anything in it, and the CronJob would never exist.

## Expected upgrade plan (what a correct agent output looks like)

One combined sequence of control plane (CP) and node pool steps. Nodes go **1.32 → 1.34 → 1.36**, so node skew never exceeds **2 minors**, which is inside the limit on every platform.

| # | Step | Must be done first | Skew (CP − nodes) |
|---|---|---|---|
| 0 | **Prep, still on 1.32** | Fix F02 (already broken). Argo CD → 3.4 (F05 step 1). cert-manager → 1.20 (F04 step 1). EKS node groups → AL2023 (F10; AL2 is already unpatched). Fix F08 / F09. Plan the ingress-nginx migration (F06) | 0 |
| 1 | CP 1.32 → 1.33 | Step 0. Endpoints warnings start (F07) | 1 |
| 2 | CP 1.33 → **1.34 !** | Chart `kubeVersion` widened (F01) | 2 |
| 3 | **Node roll 1.32 → 1.34** | F08, F09 (drain + data), F10 (EKS) | 0 |
| 4 | Argo CD → 3.5 (F05 step 2), cert-manager → 1.21 (F04 step 2) | CP ≥ 1.33 (lower bound of both new ranges) | 0 |
| 5 | CP 1.34 → 1.35 | | 1 |
| 6 | Node prep: cgroup v2 (F14), containerd 2 (F03) | Must land before any kubelet ≥ 1.35 | 1 |
| 7 | CP 1.35 → 1.36 | Step 4 | 2 |
| 8 | **Node roll 1.34 → 1.36** | Step 6 | 0 |

cgroup v1 (F14) and containerd 1.x (F03) are **kubelet-side**, so they bite at the **1.36 node roll**, not at a control plane hop. This is the kind of detail a version-by-version checklist misses.

## Readiness score and gate

Rule: **start at 100, subtract 8 per Blocker, 5 per High, 2 per Advisory.** Findings that only appear after a hop are not counted. F07 is Advisory and counted once (its static evidence exists today).

**Gate (step 5 of the pipeline):** the agent suggests **Ready** only if
1. score ≥ threshold (80), **and**
2. **no open Blocker** anywhere in the plan.

If (1) passes but (2) fails, the verdict is **Not Ready** regardless of the number. If both pass but High findings remain, the verdict is **Ready with conditions** and lists them. A human still approves on Git.

For the live `onprem` environment:

| State | Open findings | Score | Verdict |
|---|---|---|---|
| **Before** | Blocker F01, F02, F03 (−24). High F04, F05, F06, F08, F09 (−25). Advisory F07 (−2) | **49** | Not Ready |
| **PR merged, cluster not yet rebuilt** | Blocker F03 (−8). High F05, F06 (−10). Advisory F07 (−2) | **80** | **Not Ready**: score passes, but F03 is still an open Blocker |
| **PR merged + cluster rebuilt** | High F05, F06 (−10). Advisory F07 (−2) | **88** | Ready with conditions (F05 Argo CD v3, F06 ingress-nginx, F07 owner action) |

F04 counts as resolved once step 1 (cert-manager 1.20) is merged; step 2 is carried in the plan as a hop condition before CP 1.36.

The middle row is deliberate: it shows the gate catching a case where the number alone would say "go".

## Live vs scanned

- **onprem** is the **live** cluster: kind on the VM, created with **kind v0.26.0** and pinned by digest to `kindest/node:v1.32.0`. Live findings: F02 (failing sync), F03, F04, F05, F06, F07, F08, F09.
- **EKS / GKE / AKS** run in repo-only mode (see above). They can be created on 1.32 today, but that costs extended support / LTS fees, so only create one if the demo needs it.
- kind can't upgrade a cluster in place. That's fine for **readiness**; executing hops on a self-managed cluster would use kubeadm.
- `onprem/bootstrap.sh` also builds the `frontend` and `backend` images and loads them with `kind load docker-image`, so the cluster needs no registry.

## Validation

`ci/validate.sh` runs in CI on every change and proves the planted findings behave as described, instead of trusting this README:

| Check | Expected result |
|---|---|
| `helm template charts/three-tier --kube-version 1.32.0` | renders |
| `helm template charts/three-tier --kube-version 1.34.0` | **fails** on `kubeVersion` (F01) |
| `kustomize build platform/flowcontrol/overlays/<env>` piped to kubeconform with the 1.32 schemas | **fails** on `v1beta3` (F02) |
| Same for every other kustomization and the rendered chart, at 1.32 and the newest available schema | passes |
| `terraform init -backend=false && terraform validate` in each `infra/*` | passes (HCL is valid, only the settings are planted) |
| `grep` planted files for `planted`, `F0`, `F1`, `deprecated` | no matches (no hints for the agent) |
| Agent output (when present): evidence paths vs `.preflightignore` | no evidence from ignored paths |

## Open items to verify before implementation

These claims come from release notes and support tables and must be re-checked, with exact URLs added to Sources:

1. cert-manager **1.20** supports 1.32 to 1.35 and **1.21** supports 1.33 to 1.36.
2. Argo CD **3.4** is tested on 1.32 to 1.35 and **3.5** on 1.33 to 1.36.
3. **1.32 is an AKS LTS version** and can still be created in Oct 2026.
4. Whether the **1.36 kubelet refuses** to start on containerd 1.x or only warns. If it only warns, F03 becomes `unsupported` / High and the scores move.
5. Whether node pools may **skip a minor** (1.32 → 1.34) on each platform, especially AKS and kubeadm. If not, the node track becomes 1.32 → 1.33 → 1.34 → … on that platform.
6. GKE's node skew limit (the plan keeps skew ≤ 2, so this only matters if a platform allows less).

## Sources (checked 2026-10-19)

- Kubernetes deprecated API migration guide: kubernetes.io/docs/reference/using-api/deprecation-guide
- Kubernetes version skew policy: kubernetes.io/releases/version-skew-policy
- EKS Kubernetes version lifecycle and AL2 AMI deprecation FAQ: docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html, eks-ami-deprecation-faqs
- AKS supported Kubernetes versions and LTS: learn.microsoft.com/azure/aks/supported-kubernetes-versions
- GKE release schedule: docs.cloud.google.com/kubernetes-engine/docs/release-schedule
- Ingress NGINX retirement: kubernetes.io/blog/2025/11/11/ingress-nginx-retirement, kubernetes.io/blog/2026/01/29/ingress-nginx-statement
- cgroup v2 shift and containerd 1.x support ending in 1.36: kubernetes.io/blog/2026/10/06/kubernetes-cgroups-v2-shift, kubernetes.io/blog/2025/11/26/kubernetes-v1-35-sneak-peek
- Argo CD tested Kubernetes versions: `docs/operator-manual/tested-kubernetes-versions.md` at v2.14.0, v3.4.x, v3.5.5
- cert-manager supported releases: cert-manager.io/docs/releases
- ingress-nginx support table: repo `README.md` (main)
- kind release notes v0.26.0 (`kindest/node:v1.32.0`, containerd 1.x) and v0.27.0 (moves to containerd 2.x)
