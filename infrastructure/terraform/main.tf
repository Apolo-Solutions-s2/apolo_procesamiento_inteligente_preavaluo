# ============================================================================
# Terraform Main Configuration
# ============================================================================
# Configuración principal de recursos para el microservicio
# Apolo Procesamiento Inteligente de Documentos Financieros
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Locals - Variables Computadas
# ─────────────────────────────────────────────────────────────

locals {
  function_full_name = "${var.function_name}-${var.environment}"
  bucket_full_name   = "${var.bucket_name}-${var.environment}"
  sa_email           = "${var.service_account_name}-${var.environment}@${var.project_id}.iam.gserviceaccount.com"

  # Labels combinados con environment
  common_labels = merge(
    var.labels,
    {
      environment = var.environment
      service     = "procesamiento-inteligente"
    }
  )
}

# ─────────────────────────────────────────────────────────────
# APIs de Google Cloud - Habilitación
# ─────────────────────────────────────────────────────────────

resource "google_project_service" "required_apis" {
  for_each = toset(var.required_apis)

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# ─────────────────────────────────────────────────────────────
# Service Account - Identidad de la Cloud Function
# ─────────────────────────────────────────────────────────────

resource "google_service_account" "function_sa" {
  account_id   = "${var.service_account_name}-${var.environment}"
  display_name = "${var.service_account_display_name} (${var.environment})"
  description  = "Service Account para Cloud Function de procesamiento inteligente - ${var.environment}"
  project      = var.project_id

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Document AI Processors
# ─────────────────────────────────────────────────────────────

# Classifier Processor - Clasifica tipos de documentos
resource "google_document_ai_processor" "classifier" {
  location     = var.region
  display_name = "apolo-classifier-${var.environment}"
  type         = var.documentai_classifier_type
  project      = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Extractor Processor - Extrae datos estructurados
resource "google_document_ai_processor" "extractor" {
  location     = var.region
  display_name = "apolo-extractor-${var.environment}"
  type         = var.documentai_extractor_type
  project      = var.project_id

  depends_on = [google_project_service.required_apis]
}

# IAM para Document AI
resource "google_project_iam_member" "function_sa_documentai" {
  project = var.project_id
  role    = "roles/documentai.apiUser"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# Pub/Sub Topic para Dead Letter Queue
# ─────────────────────────────────────────────────────────────

resource "google_pubsub_topic" "dlq" {
  name    = "${var.dlq_topic_name}-${var.environment}"
  project = var.project_id

  message_retention_duration = "${var.dlq_retention_days * 24}h"

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# Subscription para DLQ (para consumo manual)
resource "google_pubsub_subscription" "dlq_pull" {
  name    = "${var.dlq_topic_name}-sub-${var.environment}"
  topic   = google_pubsub_topic.dlq.name
  project = var.project_id

  # Retener mensajes por 7 días
  message_retention_duration = "${var.dlq_retention_days * 24}h"
  retain_acked_messages      = true

  ack_deadline_seconds = 300

  labels = local.common_labels
}

# IAM para publicar al DLQ
resource "google_pubsub_topic_iam_member" "function_sa_publisher" {
  project = google_pubsub_topic.dlq.project
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# Eventarc Trigger - Activación automática en GCS
# ─────────────────────────────────────────────────────────────

resource "google_eventarc_trigger" "gcs_trigger" {
  count = var.enable_eventarc ? 1 : 0

  name     = "${var.eventarc_trigger_name}-${var.environment}"
  location = var.region
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.pdf_bucket.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.processor.name
      region  = var.region
    }
  }

  service_account = google_service_account.function_sa.email

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_cloud_run_v2_service.processor,
  ]
}

# IAM para Eventarc invocar Cloud Function
resource "google_project_iam_member" "eventarc_invoker" {
  count = var.enable_eventarc ? 1 : 0

  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# IAM Roles para Service Account
# ─────────────────────────────────────────────────────────────

# Permiso para leer/escribir en GCS
resource "google_project_iam_member" "function_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Permiso para Firestore
resource "google_project_iam_member" "function_sa_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Permiso para Cloud Logging
resource "google_project_iam_member" "function_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Permiso para Cloud Trace
resource "google_project_iam_member" "function_sa_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# Cloud Storage Bucket - Almacenamiento de PDFs
# ─────────────────────────────────────────────────────────────

resource "google_storage_bucket" "pdf_bucket" {
  name          = local.bucket_full_name
  location      = var.bucket_location
  storage_class = var.bucket_storage_class
  project       = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = var.environment == "prod" ? true : false
  }

  lifecycle_rule {
    condition {
      age = var.bucket_lifecycle_age
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.bucket_lifecycle_age * 2
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Firestore Database - Base de Datos NoSQL
# ─────────────────────────────────────────────────────────────

resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = var.firestore_database_name
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  # Solo crear en el primer despliegue
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Artifact Registry Repository - Para imágenes Docker
# ─────────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "apolo-docker-repo"
  description   = "Docker repository for Apolo microservices"
  format        = "DOCKER"
  project       = var.project_id

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Cloud Run Service v2 - Microservicio Contenerizado
# ─────────────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "processor" {
  name     = local.function_full_name
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.function_sa.email

    containers {
      image = var.cloudrun_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cloudrun_cpu
          memory = var.cloudrun_memory
        }
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "PROCESSOR_LOCATION"
        value = var.region
      }

      env {
        name  = "CLASSIFIER_PROCESSOR_ID"
        value = google_document_ai_processor.classifier.id
      }

      env {
        name  = "EXTRACTOR_PROCESSOR_ID"
        value = google_document_ai_processor.extractor.id
      }

      env {
        name  = "DLQ_TOPIC_NAME"
        value = google_pubsub_topic.dlq.name
      }

      env {
        name  = "FIRESTORE_DATABASE"
        value = var.firestore_database_name
      }

      env {
        name  = "MAX_CONCURRENT_DOCS"
        value = "8"
      }

      env {
        name  = "MAX_RETRIES"
        value = "3"
      }

      env {
        name  = "RETRY_INITIAL_DELAY"
        value = "1.0"
      }

      env {
        name  = "RETRY_MULTIPLIER"
        value = "2.0"
      }

      env {
        name  = "RETRY_MAX_DELAY"
        value = "60.0"
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }

    scaling {
      min_instance_count = var.cloudrun_min_instances
      max_instance_count = var.cloudrun_max_instances
    }

    timeout = "${var.cloudrun_timeout}s"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_artifact_registry_repository.docker_repo,
  ]
}

# ─────────────────────────────────────────────────────────────
# Cloud Run IAM - Permitir invocación desde Eventarc
# ─────────────────────────────────────────────────────────────

resource "google_cloud_run_v2_service_iam_member" "eventarc_invoker" {
  project  = google_cloud_run_v2_service.processor.project
  location = google_cloud_run_v2_service.processor.location
  name     = google_cloud_run_v2_service.processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.function_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────
# Cloud Monitoring - Alertas (solo prod)
# ─────────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "function_errors" {
  count = var.environment == "prod" && var.enable_monitoring ? 1 : 0

  display_name = "Apolo Procesamiento - Error Rate Alert"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Error rate > 5%"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${local.function_full_name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class != \"2xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = []

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Log Sink para análisis (opcional)
# ─────────────────────────────────────────────────────────────

resource "google_logging_project_sink" "function_logs" {
  count = var.enable_monitoring ? 1 : 0

  name        = "apolo-procesamiento-logs-${var.environment}"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.pdf_bucket.name}"

  filter = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${local.function_full_name}\""

  unique_writer_identity = true

  depends_on = [google_project_service.required_apis]
}
