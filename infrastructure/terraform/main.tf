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
  workflow_full_name = "${var.workflow_name}-${var.environment}"
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
# Cloud Storage Bucket - Source Code de la Cloud Function
# ─────────────────────────────────────────────────────────────

resource "google_storage_bucket" "function_source" {
  name          = "${var.project_id}-${var.environment}-gcf-source"
  location      = var.region
  storage_class = "STANDARD"
  project       = var.project_id

  uniform_bucket_level_access = true

  labels = local.common_labels

  depends_on = [google_project_service.required_apis]
}

# ─────────────────────────────────────────────────────────────
# Archivo ZIP del Código Fuente
# ─────────────────────────────────────────────────────────────

data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = var.function_source_dir
  output_path = "${path.module}/function-source.zip"
  excludes = [
    ".git",
    ".gitignore",
    "*.pyc",
    "__pycache__",
    "*.backup",
    "infrastructure",
    ".terraform",
    "*.tfstate",
    "*.tfvars",
  ]
}

# ─────────────────────────────────────────────────────────────
# Upload del Source Code a GCS
# ─────────────────────────────────────────────────────────────

resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function_source.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path

  depends_on = [data.archive_file.function_source]
}

# ─────────────────────────────────────────────────────────────
# Cloud Function v2 (2nd Gen)
# ─────────────────────────────────────────────────────────────

resource "google_cloudfunctions2_function" "processor" {
  name        = local.function_full_name
  location    = var.region
  description = var.function_description
  project     = var.project_id

  build_config {
    runtime     = var.function_runtime
    entry_point = var.function_entry_point

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = var.function_max_instances
    min_instance_count    = var.function_min_instances
    available_memory      = var.function_memory
    timeout_seconds       = var.function_timeout
    service_account_email = google_service_account.function_sa.email

    environment_variables = {
      BUCKET_NAME  = google_storage_bucket.pdf_bucket.name
      ENVIRONMENT  = var.environment
      PROJECT_ID   = var.project_id
      REGION       = var.region
    }

    ingress_settings = var.ingress_settings

    # Solo permitir invocación desde service accounts
    all_traffic_on_latest_revision = true
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket_object.function_source,
  ]
}

# ─────────────────────────────────────────────────────────────
# IAM para Cloud Function - Invoker Role
# ─────────────────────────────────────────────────────────────

# Permitir invocación desde Cloud Workflows
resource "google_cloud_run_service_iam_member" "workflow_invoker" {
  project  = google_cloudfunctions2_function.processor.project
  location = google_cloudfunctions2_function.processor.location
  service  = google_cloudfunctions2_function.processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# Service Account para Cloud Workflows
# ─────────────────────────────────────────────────────────────

resource "google_service_account" "workflow_sa" {
  account_id   = "apolo-workflow-sa-${var.environment}"
  display_name = "Apolo Workflow Service Account (${var.environment})"
  description  = "Service Account para Cloud Workflows - ${var.environment}"
  project      = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Permiso para invocar Cloud Functions
resource "google_project_iam_member" "workflow_sa_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Permiso para Cloud Run (Cloud Functions v2)
resource "google_project_iam_member" "workflow_sa_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# Permiso para logs
resource "google_project_iam_member" "workflow_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow_sa.email}"
}

# ─────────────────────────────────────────────────────────────
# Cloud Workflows - Orquestación
# ─────────────────────────────────────────────────────────────

resource "google_workflows_workflow" "main" {
  name            = local.workflow_full_name
  region          = var.region
  description     = var.workflow_description
  project         = var.project_id
  service_account = google_service_account.workflow_sa.id

  source_contents = templatefile(var.workflow_source_file, {
    processor_url = google_cloudfunctions2_function.processor.service_config[0].uri
  })

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_cloudfunctions2_function.processor,
  ]
}

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
      filter          = "resource.type = \"cloud_function\" AND resource.labels.function_name = \"${local.function_full_name}\" AND metric.type = \"cloudfunctions.googleapis.com/function/execution_count\" AND metric.labels.status != \"ok\""
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
  destination = "storage.googleapis.com/${google_storage_bucket.function_source.name}"

  filter = "resource.type = \"cloud_function\" AND resource.labels.function_name = \"${local.function_full_name}\""

  unique_writer_identity = true

  depends_on = [google_project_service.required_apis]
}
