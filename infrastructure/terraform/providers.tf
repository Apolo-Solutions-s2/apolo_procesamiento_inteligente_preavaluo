# ============================================================================
# Terraform Providers Configuration
# ============================================================================
# Defines required Terraform version, providers, and backend configuration
# ============================================================================

terraform {
  required_version = "1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.12.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.12.0"
    }
  }

  backend "gcs" {
    bucket = "apolo-tf-state-bucket"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}