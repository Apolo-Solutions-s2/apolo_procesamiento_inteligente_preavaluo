# ============================================================================
# Terraform Variables - Development Environment
# ============================================================================
# Configuración específica para el ambiente de desarrollo
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Proyecto y Región
# ─────────────────────────────────────────────────────────────

project_id  = "apolo-dev-project"
region      = "us-south1"
zone        = "us-south1-a"
environment = "dev"

# ─────────────────────────────────────────────────────────────
# Cloud Function - Configuración Dev
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - DEV"
function_runtime     = "python311"
function_entry_point = "document_processor"

# Dev: timeouts y recursos reducidos
function_timeout       = 300  # 5 minutos (vs 9 en prod)
function_memory        = "512M"
function_min_instances = 0  # Sin instancias permanentes
function_max_instances = 3  # Límite bajo para dev

# ─────────────────────────────────────────────────────────────
# Cloud Storage
# ─────────────────────────────────────────────────────────────

bucket_name          = "apolo-preavaluos-pdf"
bucket_location      = "US-SOUTH1"
bucket_storage_class = "STANDARD"
bucket_lifecycle_age = 30  # Mover a nearline después de 30 días en dev

# ─────────────────────────────────────────────────────────────
# Firestore
# ─────────────────────────────────────────────────────────────

firestore_database_name      = "(default)"
firestore_location           = "nam5"
firestore_collection_ttl_days = 90  # Retención corta en dev

# ─────────────────────────────────────────────────────────────
# Cloud Workflows
# ─────────────────────────────────────────────────────────────

workflow_name        = "apolo-procesamiento-workflow"
workflow_description = "Orquestación del procesamiento de documentos - DEV"

# ─────────────────────────────────────────────────────────────
# Networking y Seguridad
# ─────────────────────────────────────────────────────────────

# Dev: Permitir acceso interno solamente
ingress_settings     = "ALLOW_INTERNAL_ONLY"
enable_vpc_connector = false

# ─────────────────────────────────────────────────────────────
# Monitoreo y Logging
# ─────────────────────────────────────────────────────────────

enable_monitoring    = true
log_retention_days   = 7   # Solo 7 días en dev
enable_tracing       = true

# ─────────────────────────────────────────────────────────────
# Labels y Tags
# ─────────────────────────────────────────────────────────────

labels = {
  managed_by  = "terraform"
  project     = "apolo"
  module      = "procesamiento-inteligente"
  environment = "dev"
  cost_center = "desarrollo"
  team        = "apolo-dev"
}
