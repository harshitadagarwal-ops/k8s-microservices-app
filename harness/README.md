# Harness — Preflight Upgrade Planner

Pipeline-as-code for the Kubernetes Preflight worker agent.

- Org: `Worker_Agents_Hackathon`
- Project: `Team_KubePilots`
- Pipeline: `K8sPreflightAgentPipelineKubePilot` (`k8s-upgrade-planner.yaml`)
- Input set: `kube-pilot-eks` (`input-set-kube-pilot.yaml`)

This is modeled on the team's `K8sPreflightAgentPipeline`, which uses the real
Harness **`type: Agent`** step (referencing a named custom agent) — not the
`harnessAI@1.0.0` plugin form.

## Pipeline shape

```
Stage: Build (CI)
  - parallel security scans: Gitleaks, Semgrep, OsvScanner
  - Agent step: ca_preflight_k8s_upgrade_readiness_agent   (DISABLED: condition "false")
Stage: Approval
  - HarnessApproval -> KubePilotsUserGroup
```

The agent step is intentionally **disabled** (`when.condition: "false"`). Flip it
to `"true"` to actually run the agent.

## Runtime inputs

| Variable | Default | Notes |
|---|---|---|
| `current_version` | `1.34` | real cluster version, no `v` prefix |
| `target_version` | `1.35` | next minor to plan to |
| `target_env` | `<+input>` | allowedValues: prod-eks, staging-gke, dev-aks, onprem |
| codebase `build` | `<+input>` | branch/tag of the repo to scan |

## Passing inputs to the custom agent

Pipeline variables are mapped to the agent via `agentSettings` on the Agent step:

```yaml
agentSettings:
  current_version: <+pipeline.variables.current_version>
  target_version: <+pipeline.variables.target_version>
  target_env: <+pipeline.variables.target_env>
```

The keys under `agentSettings` **must match the Input names defined on the agent**
(agent builder -> Inputs -> Add). If the agent defines different identifiers,
rename the keys here to match.

## Testing

1. **Agent alone (fastest):** in the agent builder, open the Run/Test panel, set
   the Inputs (current_version=1.34, target_version=1.35, target_env=prod-eks),
   and run interactively. Confirms model + MCP connectors work.
2. **Via pipeline:** set the agent step `condition: "true"`, Run, pick the
   `kube-pilot-eks` input set, approve at the Approval stage.

## Connectors used (project-level)

| Purpose | Connector | Status |
|---|---|---|
| Model (reasoning) | OpenAI (`avyka_openai_token`) | connected |
| Kubernetes (read cluster) | `kube-pilot-avyka-eks` | connected |
| Git (read repo / open PR) | `k8s-microservice-app` | connected |
| AWS (EKS platform checks) | not yet created | needs delegate IRSA (read-only) |

Cluster/Git access is attached to the agent as **MCP connectors** in the agent
builder (not a YAML field on the step).

## Least-privilege notes (from the agent instructions)

- Kubernetes access read-only, excluding Secrets.
- Git starts read-only; branch/PR only for the fix-PR task.
- No live upgrades / no `eks:Update*` — the agent only plans and opens PRs.
