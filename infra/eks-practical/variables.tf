variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region for the cluster."
}

variable "cluster_name" {
  type        = string
  default     = "kube-pilots"
  description = "EKS cluster name. Also used to name the VPC and IAM roles."
}

variable "cluster_version" {
  type        = string
  default     = "1.32"
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

variable "tags" {
  type = map(string)
  default = {
    project     = "kube-pilots"
    environment = "practical"
    owner       = "harshita"
  }
  description = "Tags applied to all resources."
}
