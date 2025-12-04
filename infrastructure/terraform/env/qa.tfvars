# ============================================================================
# Terraform Variables - QA Environment
# ============================================================================
# Configuración específica para el ambiente de QA/Testing
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Proyecto y Región
# ─────────────────────────────────────────────────────────────

project_id  = "apolo-qa-project"
region      = "us-south1"
zone        = "us-south1-a"
environment = "qa"

# ─────────────────────────────────────────────────────────────
# Cloud Function - Configuración QA
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - QA"
function_runtime     = "python311"
function_entry_point = "document_processor"

# QA: Recursos intermedios para testing realista
function_timeout       = 450  # 7.5 minutos
function_memory        = "512M"
function_min_instances = 0
function_max_instances = 5  # Más que dev, menos que prod

# ─────────────────────────────────────────────────────────────
# Cloud Storage
# ─────────────────────────────────────────────────────────────

bucket_name          = "apolo-preavaluos-pdf"
bucket_location      = "US-SOUTH1"
bucket_storage_class = "STANDARD"
bucket_lifecycle_age = 60  # Mover a nearline después de 60 días en QA

# ─────────────────────────────────────────────────────────────
# Firestore
# ─────────────────────────────────────────────────────────────

firestore_database_name      = "(default)"
firestore_location           = "nam5"
firestore_collection_ttl_days = 180  # Retención media en QA

# ─────────────────────────────────────────────────────────────
# Cloud Workflows
# ─────────────────────────────────────────────────────────────

workflow_name        = "apolo-procesamiento-workflow"
workflow_description = "Orquestación del procesamiento de documentos - QA"

# ─────────────────────────────────────────────────────────────
# Networking y Seguridad
# ─────────────────────────────────────────────────────────────

# QA: Solo acceso interno
ingress_settings     = "ALLOW_INTERNAL_ONLY"
enable_vpc_connector = false

# ─────────────────────────────────────────────────────────────
# Monitoreo y Logging
# ─────────────────────────────────────────────────────────────

enable_monitoring    = true
log_retention_days   = 30  # 30 días para análisis de bugs
enable_tracing       = true

# ─────────────────────────────────────────────────────────────
# Labels y Tags
# ─────────────────────────────────────────────────────────────

labels = {
  managed_by  = "terraform"
  project     = "apolo"
  module      = "procesamiento-inteligente"
  environment = "qa"
  cost_center = "qa-testing"
  team        = "apolo-qa"
}
