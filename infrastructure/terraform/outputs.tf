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
# Cloud Function Outputs
# ─────────────────────────────────────────────────────────────

output "function_name" {
  description = "Nombre completo de la Cloud Function"
  value       = google_cloudfunctions2_function.processor.name
}

output "function_url" {
  description = "URL HTTP de la Cloud Function"
  value       = google_cloudfunctions2_function.processor.service_config[0].uri
  sensitive   = false
}

output "function_service_account" {
  description = "Service Account de la Cloud Function"
  value       = google_service_account.function_sa.email
}

output "function_id" {
  description = "ID completo de la Cloud Function"
  value       = google_cloudfunctions2_function.processor.id
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

output "function_source_bucket" {
  description = "Bucket donde se almacena el código fuente"
  value       = google_storage_bucket.function_source.name
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
# Cloud Workflows Outputs
# ─────────────────────────────────────────────────────────────

output "workflow_name" {
  description = "Nombre del Cloud Workflow"
  value       = google_workflows_workflow.main.name
}

output "workflow_id" {
  description = "ID del Cloud Workflow"
  value       = google_workflows_workflow.main.id
}

output "workflow_service_account" {
  description = "Service Account del Workflow"
  value       = google_service_account.workflow_sa.email
}

output "workflow_revision_id" {
  description = "ID de revisión del Workflow"
  value       = google_workflows_workflow.main.revision_id
}

# ─────────────────────────────────────────────────────────────
# Service Accounts Outputs
# ─────────────────────────────────────────────────────────────

output "service_accounts" {
  description = "Todas las service accounts creadas"
  value = {
    function = google_service_account.function_sa.email
    workflow = google_service_account.workflow_sa.email
  }
}

# ─────────────────────────────────────────────────────────────
# Testing y Debug
# ─────────────────────────────────────────────────────────────

output "curl_test_command" {
  description = "Comando curl para testear la Cloud Function"
  value = <<-EOT
    curl -X POST ${google_cloudfunctions2_function.processor.service_config[0].uri} \
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

output "workflow_execution_command" {
  description = "Comando para ejecutar el workflow manualmente"
  value = <<-EOT
    gcloud workflows execute ${google_workflows_workflow.main.name} \
      --location=${var.region} \
      --data='{
        "folder_prefix": "TEST-001/",
        "preavaluo_id": "TEST-001"
      }'
  EOT
}

# ─────────────────────────────────────────────────────────────
# Monitoring URLs
# ─────────────────────────────────────────────────────────────

output "monitoring_urls" {
  description = "URLs para monitoreo en GCP Console"
  value = {
    function_logs = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_function%22%0Aresource.labels.function_name%3D%22${google_cloudfunctions2_function.processor.name}%22?project=${var.project_id}"
    
    function_metrics = "https://console.cloud.google.com/functions/details/${var.region}/${google_cloudfunctions2_function.processor.name}?project=${var.project_id}"
    
    workflow_executions = "https://console.cloud.google.com/workflows/workflow/${var.region}/${google_workflows_workflow.main.name}/executions?project=${var.project_id}"
    
    firestore_console = "https://console.cloud.google.com/firestore/databases/-default-/data/panel?project=${var.project_id}"
    
    storage_bucket = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.pdf_bucket.name}?project=${var.project_id}"
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
    cloud_function      = google_cloudfunctions2_function.processor.name
    workflow            = google_workflows_workflow.main.name
    pdf_bucket          = google_storage_bucket.pdf_bucket.name
    firestore_database  = google_firestore_database.main.name
    service_accounts    = 2
    environment         = var.environment
  }
}
