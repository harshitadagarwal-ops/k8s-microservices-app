# Upgrade plan: 1.34 -> 1.36 (MOCK)
## Before you start
1. Take an etcd/cluster backup and confirm you can roll back (restore point recorded in the change ticket).
## Hop 1: 1.34 -> 1.35
No removed APIs found. Upgrade control plane, then node groups.
## Hop 2: 1.35 -> 1.36 (FLAGGED)
`k8s/apps/widget.yaml` uses `example.io/v1beta1`, removed in 1.36. Fix PR: https://github.com/example-org/k8s-microservices-app/pull/12
Support: current version STANDARD until 2027-01-01, urgency LOW.
