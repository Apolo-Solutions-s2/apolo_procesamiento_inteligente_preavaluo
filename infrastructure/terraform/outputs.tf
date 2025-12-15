# ============================================================================
# Terraform Outputs
# ============================================================================
# Outputs importantes para referencia y debugging
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Información General
# ─────────────────────────────────────────────────────────────

output "environment" {
  description = "Ambiente desplegado"
  value       = var.environment
}

output "project_id" {
  description = "ID del proyecto de GCP"
  value       = var.project_id
}

output "region" {
  description = "Región de despliegue"
  value       = var.region
}

# ─────────────────────────────────────────────────────────────
# Cloud Run Outputs
# ─────────────────────────────────────────────────────────────

output "cloudrun_service_name" {
  description = "Nombre del Cloud Run service"
  value       = google_cloud_run_v2_service.processor.name
}

output "cloudrun_service_url" {
  description = "URL del Cloud Run service"
  value       = google_cloud_run_v2_service.processor.uri
  sensitive   = false
}

output "cloudrun_service_id" {
  description = "ID completo del Cloud Run service"
  value       = google_cloud_run_v2_service.processor.id
}

output "function_name" {
  description = "Nombre del servicio (legacy compatibility)"
  value       = google_cloud_run_v2_service.processor.name
}

output "function_url" {
  description = "URL del servicio (legacy compatibility)"
  value       = google_cloud_run_v2_service.processor.uri
  sensitive   = false
}

output "function_service_account" {
  description = "Service Account del servicio"
  value       = google_service_account.function_sa.email
}

output "function_id" {
  description = "ID completo del servicio (legacy compatibility)"
  value       = google_cloud_run_v2_service.processor.id
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository para imágenes Docker"
  value       = google_artifact_registry_repository.docker_repo.id
}

# ─────────────────────────────────────────────────────────────
# Cloud Storage Outputs
# ─────────────────────────────────────────────────────────────

output "pdf_bucket_name" {
  description = "Nombre del bucket de PDFs"
  value       = google_storage_bucket.pdf_bucket.name
}

output "pdf_bucket_url" {
  description = "URL del bucket de PDFs"
  value       = google_storage_bucket.pdf_bucket.url
}

output "pdf_bucket_self_link" {
  description = "Self link del bucket de PDFs"
  value       = google_storage_bucket.pdf_bucket.self_link
}

# ─────────────────────────────────────────────────────────────
# Firestore Outputs
# ─────────────────────────────────────────────────────────────

output "firestore_database_name" {
  description = "Nombre de la base de datos Firestore"
  value       = google_firestore_database.main.name
}

output "firestore_location" {
  description = "Ubicación de Firestore"
  value       = google_firestore_database.main.location_id
}

# ─────────────────────────────────────────────────────────────
# Document AI Outputs
# ─────────────────────────────────────────────────────────────

output "classifier_processor_id" {
  description = "ID del Document AI Classifier processor"
  value       = google_document_ai_processor.classifier.id
}

output "classifier_processor_name" {
  description = "Nombre del Document AI Classifier processor"
  value       = google_document_ai_processor.classifier.display_name
}

output "extractor_processor_id" {
  description = "ID del Document AI Extractor processor"
  value       = google_document_ai_processor.extractor.id
}

output "extractor_processor_name" {
  description = "Nombre del Document AI Extractor processor"
  value       = google_document_ai_processor.extractor.display_name
}

# ─────────────────────────────────────────────────────────────
# Pub/Sub DLQ Outputs
# ─────────────────────────────────────────────────────────────

output "dlq_topic_name" {
  description = "Nombre del Pub/Sub topic para DLQ"
  value       = google_pubsub_topic.dlq.name
}

output "dlq_topic_id" {
  description = "ID completo del topic DLQ"
  value       = google_pubsub_topic.dlq.id
}

output "dlq_subscription_name" {
  description = "Nombre de la subscription DLQ"
  value       = google_pubsub_subscription.dlq_pull.name
}

# ─────────────────────────────────────────────────────────────
# Eventarc Outputs
# ─────────────────────────────────────────────────────────────

output "eventarc_trigger_name" {
  description = "Nombre del Eventarc trigger (si está habilitado)"
  value       = var.enable_eventarc ? google_eventarc_trigger.gcs_trigger[0].name : "disabled"
}

output "eventarc_trigger_id" {
  description = "ID del Eventarc trigger (si está habilitado)"
  value       = var.enable_eventarc ? google_eventarc_trigger.gcs_trigger[0].id : "disabled"
}

# ─────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────
# Service Accounts Outputs
# ─────────────────────────────────────────────────────────────

output "service_accounts" {
  description = "Service account del Cloud Run service"
  value = {
    function = google_service_account.function_sa.email
  }
}

# ─────────────────────────────────────────────────────────────
# Testing y Debug
# ─────────────────────────────────────────────────────────────

output "curl_test_command" {
  description = "Comando curl para testear el Cloud Run service"
  value = <<-EOT
    curl -X POST ${google_cloud_run_v2_service.processor.uri} \
      -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
      -H "Content-Type: application/json" \
      -d '{
        "folioId": "TEST-001",
        "fileId": "test.pdf",
        "gcs_pdf_uri": "gs://${google_storage_bucket.pdf_bucket.name}/test/test.pdf",
        "workflow_execution_id": "manual-test"
      }'
  EOT
}

# ─────────────────────────────────────────────────────────────
# Monitoring URLs
# ─────────────────────────────────────────────────────────────

output "monitoring_urls" {
  description = "URLs para monitoreo en GCP Console"
  value = {
    cloudrun_logs = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_run_revision%22%0Aresource.labels.service_name%3D%22${google_cloud_run_v2_service.processor.name}%22?project=${var.project_id}"
    
    cloudrun_metrics = "https://console.cloud.google.com/run/detail/${var.region}/${google_cloud_run_v2_service.processor.name}/metrics?project=${var.project_id}"
    
    workflow_executions = "https://console.cloud.google.com/workflows/workflow/${var.region}/${google_workflows_workflow.main.name}/executions?project=${var.project_id}"
    
    firestore_console = "https://console.cloud.google.com/firestore/databases/-default-/data/panel?project=${var.project_id}"
    
    storage_bucket = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.pdf_bucket.name}?project=${var.project_id}"

    artifact_registry = "https://console.cloud.google.com/artifacts/docker/${var.project_id}/${var.region}/apolo-docker-repo?project=${var.project_id}"
  }
}

# ─────────────────────────────────────────────────────────────
# Configuración para siguiente despliegue
# ─────────────────────────────────────────────────────────────

output "deployment_info" {
  description = "Información importante para próximos despliegues"
  value = {
    terraform_version = "1.5.7"
    google_provider   = "~> 7.12.0"
    environment       = var.environment
    last_deployed     = timestamp()
  }
}

# ─────────────────────────────────────────────────────────────
# Resumen de Recursos
# ─────────────────────────────────────────────────────────────

output "resource_summary" {
  description = "Resumen de recursos creados"
  value = {
    cloud_run_service     = google_cloud_run_v2_service.processor.name
    workflow              = google_workflows_workflow.main.name
    pdf_bucket            = google_storage_bucket.pdf_bucket.name
    firestore_database    = google_firestore_database.main.name
    classifier_processor  = google_document_ai_processor.classifier.display_name
    extractor_processor   = google_document_ai_processor.extractor.display_name
    dlq_topic            = google_pubsub_topic.dlq.name
    eventarc_trigger     = var.enable_eventarc ? google_eventarc_trigger.gcs_trigger[0].name : "disabled"
    artifact_registry    = google_artifact_registry_repository.docker_repo.id
    service_accounts     = 2
    environment          = var.environment
    region               = var.region
  }
}
