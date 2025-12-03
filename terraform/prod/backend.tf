terraform {
  backend "gcs" {
    bucket = "my-terraform-state-prod"
    prefix = "cloud-run/document-processor"
  }
}