# Upgrade plan: 1.34 -> 1.36 (MOCK)
## Before you start
1. Take a cluster backup and confirm you can roll back.
## Hops
1.34 -> 1.35, then 1.35 -> 1.36. `k8s/apps/widget.yaml` uses `example.io/v1beta1`, removed in 1.36 (PR #12).
Support: standard support ends 2026-03-15 and the extended-support fee will be $950 per month. Also found 3 CRITICAL RBAC issues.
