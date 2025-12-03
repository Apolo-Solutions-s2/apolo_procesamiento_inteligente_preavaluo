terraform {
  backend "gcs" {
    bucket = "my-terraform-state-qa"
    prefix = "cloud-run/document-processor"
  }
}