terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.20"
    }
  }

  backend "gcs" {
    bucket = "example-tfstate-staging"
    prefix = "gke/staging-gke"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "staging" {
  name     = "staging-gke"
  location = var.region

  min_master_version = "1.32"

  release_channel {
    channel = "EXTENDED"
  }

  network    = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "general" {
  name     = "general"
  cluster  = google_container_cluster.staging.name
  location = var.region
  version  = "1.32"

  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "e2-standard-4"
    image_type   = "COS_CONTAINERD"

    linux_node_config {
      cgroup_mode = "CGROUP_MODE_V1"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
