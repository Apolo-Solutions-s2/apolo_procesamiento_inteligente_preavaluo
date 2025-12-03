terraform {
  backend "gcs" {
    bucket = "my-terraform-state-dev"
    prefix = "cloud-run/document-processor"
  }
}