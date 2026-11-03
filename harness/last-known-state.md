# Last-known live state (captured before teardown)

Snapshot taken just before `terraform destroy`, for reference on rebuild.

## Cluster
- Name: kube-pilot
- Version: 1.34 (ACTIVE)
- Endpoint: https://525B9DB95E76E4B8A84255B84037A93B.gr7.us-east-1.eks.amazonaws.com
  (NOTE: endpoint/cert change on recreate — re-test the Harness K8s connector after rebuild)

## Ingress / ALB (will be recreated with a NEW DNS name on rebuild)
- demo/frontend  class=alb  ADDRESS=k8s-demo-frontend-15f51ee5f2-2012231754.us-east-1.elb.amazonaws.com  :80

## Workloads (all defined in manifests-eks/ — recreated by kubectl apply -k)
- demo: backend x2, frontend x2, mysql x1
- harness-delegate-ng: helm-delegate
- kube-system: aws-load-balancer-controller x2, coredns, ebs-csi-controller, vpc-cni, kube-proxy

## Preserved across destroy (reused on rebuild)
- ECR: 105673693246.dkr.ecr.us-east-1.amazonaws.com/three-tier/{frontend,backend}:latest (multi-arch)
- S3 state: kube-pilot-tfstate-105673693246-use1 + DynamoDB kube-pilot-tflock

## Not backed up (demo data, intentionally discarded)
- MySQL EBS volume contents (messages) — throwaway demo data.

See REBUILD.md for the full restore procedure.
