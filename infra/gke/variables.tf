variable "project_id" {
  type    = string
  default = "example-staging"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "network" {
  type    = string
  default = "staging-vpc"
}

variable "subnetwork" {
  type    = string
  default = "staging-gke-nodes"
}
