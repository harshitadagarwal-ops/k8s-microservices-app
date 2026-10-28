# Harness — Preflight Upgrade Planner

Pipeline-as-code skeleton for the Kubernetes Preflight worker agent, matching the
architecture diagram (`diagrams/`).

- Org: `Worker_Agents_Hackathon`
- Project: `Team_KubePilots`
- Pipeline: `k8s-upgrade-planner`
- File: `k8s-upgrade-planner.yaml`

## What it is

A read-only, PR-based upgrade-readiness agent. It scans a cluster + repo, scores
readiness, plans the hops, opens a **fix PR**, waits for **human approval**, then
notifies. It never applies changes to the live cluster.

### The 7 steps (sequential)

1. Connect & Scan — read cluster (K8s connector) + repo (Git connector)
2. Interpret Findings — LLM analysis vs official K8s/cloud docs
3. Plan Upgrade Hops — one minor per hop, separate control-plane / node-pool tracks
4. Score & Raise Fix PR — readiness score + a Git branch/PR with fixes
5. Review Gate — Harness Approval (human; reject = re-fix)
6. Document & Link — final report + official release links, stored as artifact
7. Notify User Group — verdict + report link + PR link

## Connectors used

| Purpose | Connector | Status |
|---|---|---|
| LLM (reasoning) | `connector_Anthropic_1033` | fix if Test fails |
| Kubernetes (read cluster) | `kube-pilot-avyka-eks` | created |
| Git (read repo / open PR) | `k8s-microservice-app` | created |
| AWS (EKS platform checks: add-on versions, IRSA) | not yet created | needs delegate IRSA (read-only) |

## Runtime inputs (Input Set)

- `current_version` (e.g. 1.32)
- `target_version` (e.g. 1.33)
- `notify_usergroup` (Harness user group)
- `target_environment` (prod-eks | staging-gke | dev-aks | onprem)

## How to use

This YAML is a **starting skeleton**, not a guaranteed byte-perfect import.
Harness step/connector schemas vary by version. Recommended path:

1. In Harness, build the pipeline with the UI ("Create with AI" / YAML builder)
   and use this file as the reference for structure, prompts, and wiring.
2. Verify the fields marked `# verify` against your project's step schema:
   - the `harnessAI@1.0.0` step type and how tool connectors are attached
   - the Notify step vs a pipeline Notification rule
   - the delegate selector tag
3. Fix the Anthropic connector (Test must pass) before running.
4. Add the AWS read-only connector (via delegate IRSA) for full EKS platform
   findings.

## Least-privilege notes (from the agent instructions)

- Kubernetes access should be **read-only** and must **exclude Secrets**.
- Git starts read-only; branch/PR permission only for step 4.
- No `eks:Update*` / no live changes — the agent only plans and opens PRs.
