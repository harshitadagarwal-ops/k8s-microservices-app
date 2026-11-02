variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the cluster."
}

variable "cluster_name" {
  type        = string
  default     = "kube-pilot"
  description = "EKS cluster name. Also used to name the VPC and IAM roles."
}

variable "cluster_version" {
  type        = string
  default     = "1.34"
  description = "Kubernetes control plane version."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC."
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types for the managed node group."
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "enable_lb_controller" {
  type        = bool
  default     = true
  description = "Install the AWS Load Balancer Controller (provisions ALB/NLB for Ingress / LoadBalancer services)."
}

variable "lb_controller_chart_version" {
  type        = string
  default     = "1.8.1"
  description = "Helm chart version for aws-load-balancer-controller."
}

variable "tags" {
  type = map(string)
  # NOTE: left empty because the Avyka account guardrail denies iam:TagRole /
  # iam:TagPolicy. Any non-empty tag causes IAM role/policy creation to fail
  # with AccessDenied. Set tags here only if the account later allows IAM tagging.
  default     = {}
  description = "Tags applied to all resources. Kept empty due to IAM-tagging guardrail on this account."
}
