# ============================================================================
# Terraform Variables - Production Environment
# ============================================================================
# Configuración específica para el ambiente de producción
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Proyecto y Región
# ─────────────────────────────────────────────────────────────

project_id  = "apolo-prod-project"
region      = "us-south1"
zone        = "us-south1-a"
environment = "prod"

# ─────────────────────────────────────────────────────────────
# Cloud Function - Configuración Production
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - PRODUCTION"
function_runtime     = "python311"
function_entry_point = "document_processor"

# Prod: Máximos recursos para confiabilidad
function_timeout       = 540  # 9 minutos (máximo para Cloud Functions)
function_memory        = "1Gi"  # 1GB para procesamiento pesado
function_min_instances = 1      # Al menos 1 instancia caliente
function_max_instances = 10     # Escalado hasta 10 instancias

# ─────────────────────────────────────────────────────────────
# Cloud Storage
# ─────────────────────────────────────────────────────────────

bucket_name          = "apolo-preavaluos-pdf"
bucket_location      = "US-SOUTH1"
bucket_storage_class = "STANDARD"
bucket_lifecycle_age = 90  # Mover a nearline después de 90 días

# ─────────────────────────────────────────────────────────────
# Firestore
# ─────────────────────────────────────────────────────────────

firestore_database_name      = "(default)"
firestore_location           = "nam5"
firestore_collection_ttl_days = 365  # Retención completa de 1 año

# ─────────────────────────────────────────────────────────────
# Cloud Workflows
# ─────────────────────────────────────────────────────────────

workflow_name        = "apolo-procesamiento-workflow"
workflow_description = "Orquestación del procesamiento de documentos - PRODUCTION"

# ─────────────────────────────────────────────────────────────
# Networking y Seguridad
# ─────────────────────────────────────────────────────────────

# Prod: Solo acceso interno (máxima seguridad)
ingress_settings     = "ALLOW_INTERNAL_ONLY"
enable_vpc_connector = false

# ─────────────────────────────────────────────────────────────
# Monitoreo y Logging
# ─────────────────────────────────────────────────────────────

enable_monitoring    = true
log_retention_days   = 90  # 90 días para compliance y auditoría
enable_tracing       = true

# ─────────────────────────────────────────────────────────────
# Labels y Tags
# ─────────────────────────────────────────────────────────────

labels = {
  managed_by  = "terraform"
  project     = "apolo"
  module      = "procesamiento-inteligente"
  environment = "prod"
  cost_center = "produccion"
  team        = "apolo-prod"
  criticality = "high"
  compliance  = "required"
}
