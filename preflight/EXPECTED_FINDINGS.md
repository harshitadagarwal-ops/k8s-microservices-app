# Expected findings (answer key)

Use this to grade a Preflight run. It is excluded from the scan by `.preflightignore`. Rationale, sources and the full upgrade sequence are in [PREFLIGHT_AGENT_README.md](../PREFLIGHT_AGENT_README.md).

Run: `current_version = 1.32`, `target_version = 1.36`.

## Where each finding lives

| ID | Env | Severity | Hits at | Evidence the agent should cite | Live check (onprem only) | Expected in fix PR |
|----|-----|----------|---------|--------------------------------|--------------------------|--------------------|
| F01 | all | Blocker | CP 1.34 | `charts/three-tier/Chart.yaml:7` | `helm template … --kube-version 1.34.0` fails | Widen `kubeVersion` to `<1.37.0-0` |
| F02 | all | Blocker | already (1.32) | `platform/flowcontrol/base/flowschema.yaml:2`, `prioritylevel.yaml:2` | `kubectl -n argocd get app flowcontrol` → `SyncFailed` | `apiVersion: flowcontrol.apiserver.k8s.io/v1` |
| F03 | onprem | Blocker (verify) | node roll 1.36 | `onprem/kind-config.yaml:11,44,46`; `onprem/bootstrap.sh` (`KIND_VERSION`) | `kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'` → `containerd://1.7.x` | kind ≥ v0.27.0 + matching `kindest/node:v1.32.x@sha256:…`; note that the cluster must be recreated |
| F04 | all | High | CP 1.33 (step 1), CP 1.36 (step 2) | `gitops/<env>/apps.yaml` cert-manager `targetRevision: v1.16.2` | `kubectl -n cert-manager get deploy cert-manager -o jsonpath='{..image}'` | `v1.20.x` now; step 2 (`v1.21.x`) listed as a hop condition |
| F05 | all | High | now + CP 1.36 | `platform/argocd-install/kustomization.yaml:6` (v2.14.0) | `kubectl -n argocd get deploy argocd-server -o jsonpath='{..image}'` | **Not** in PR. Plan says 3.4 then 3.5, v2 → v3 migration |
| F06 | all | High | now (retired) | `gitops/<env>/apps.yaml` ingress-nginx `targetRevision: 4.11.3` | `kubectl -n ingress-nginx get deploy -o jsonpath='{..image}'` | **Not** in PR. Migration recommended |
| F07 | onprem | Advisory | CP 1.33 (warnings) | `platform/service-inventory/base/rbac.yaml:12`, `cronjob.yaml:28` | `kubectl -n reporting get jobs` (one every 5 min); audit log on the control plane node: `docker exec preflight-onprem-control-plane grep endpoints /var/log/kubernetes/kube-apiserver-audit.log` | **Not** in PR. Owner moves to EndpointSlices |
| F08 | onprem | High | every node roll | `charts/three-tier/values-onprem.yaml:15` + `mysql.replicas: 1` | `kubectl -n demo get pdb mysql -o jsonpath='{.status.disruptionsAllowed}'` → `0` | `pdb.maxUnavailable: 1`, flagged for review |
| F09 | onprem | High | every node roll | `charts/three-tier/values-onprem.yaml:12` | `kubectl -n demo get deploy mysql -o jsonpath='{..volumes}'` shows `emptyDir` | `persistence.enabled: true` |
| F10 | prod-eks | Blocker | first node roll | `infra/eks/main.tf:49` | repo-only | `ami_type = "AL2023_x86_64_STANDARD"`; user data (`yum`) flagged for review |
| F11 | prod-eks | High | every hop | `infra/eks/main.tf:27,37,40,43` | repo-only | Per-hop add-on versions |
| F12 | prod-eks | Advisory | n/a | `infra/eks/main.tf:27` (1.32, after Mar 23, 2026) | repo-only | Cost section only |
| F13 | prod-eks | Advisory | n/a | `charts/three-tier/values-prod-eks.yaml:20` | repo-only | Platform note only |
| F14 | staging-gke | Blocker | node roll 1.36 (kubelet ≥ 1.35) | `infra/gke/main.tf:62` | repo-only | `CGROUP_MODE_V2` |
| F15 | staging-gke | Advisory | n/a | `infra/gke/main.tf:29` | repo-only | Cost section only |
| F16 | dev-aks | Advisory | n/a | `infra/aks/main.tf:36,37,40` | repo-only | Platform note only |

Findings for cloud envs must be marked **"not verified live"**.

## False positives to watch for

The agent should **not** report these:

- Anything under an ignored path (`manifests/`, `frontend/`, `backend/`, `README.md`, …). `ci/validate.sh` checks this when `PREFLIGHT_REPORT` is set.
- Chart templates: all use GA APIs (`apps/v1`, `policy/v1`, `networking.k8s.io/v1`, `batch/v1`).
- `service-inventory` CronJob API version (`batch/v1` is current); only its use of Endpoints matters.

## Expected verdicts (onprem)

Scoring: 100 − 8 per Blocker − 5 per High − 2 per Advisory. Ready requires score ≥ 80 **and** no open Blocker.

| State | Score | Verdict |
|---|---|---|
| Before | **49** | Not Ready |
| PR merged, cluster not rebuilt (F03 open) | **80** | Not Ready (open Blocker) |
| PR merged + `bootstrap.sh --recreate` | **88** | Ready with conditions: F05, F06, F07 |

## Expected hop flags

- Control plane: `1.32 → 1.33 → 1.34! → 1.35 → 1.36`, with `1.34` flagged (F01).
- Node pools: `1.32 → 1.34 → 1.36`, with F03 and F14 attached to the **1.36 roll**, not to a control plane hop.

## Agent report format for `ci/validate.sh`

`PREFLIGHT_REPORT` must point to JSON with at least:

```json
{ "findings": [ { "id": "…", "evidence": [ { "path": "charts/three-tier/Chart.yaml", "line": 7 } ] } ] }
```
