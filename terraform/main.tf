provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_cloud_run_service" "document_processor" {
  name     = var.service_name
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "invoker" {
  service    = google_cloud_run_service.document_processor.name
  location   = google_cloud_run_service.document_processor.location
  role       = "roles/run.invoker"
  member     = var.invoker_identity
}