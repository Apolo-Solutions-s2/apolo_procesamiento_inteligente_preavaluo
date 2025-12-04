# ============================================================================
# Terraform Variables - Template/Example
# ============================================================================
# Este archivo sirve como plantilla para crear tus archivos .tfvars
# Copia este archivo y ajusta los valores según tu proyecto
# ============================================================================

# ─────────────────────────────────────────────────────────────
# IMPORTANTE: Actualiza estos valores antes de usar
# ─────────────────────────────────────────────────────────────

# Proyecto y Región
project_id  = "your-gcp-project-id"        # Actualizar con tu project ID
region      = "us-south1"
zone        = "us-south1-a"
environment = "dev"                         # dev, qa o prod

# Cloud Function
function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros"
function_runtime     = "python311"
function_entry_point = "document_processor"
function_timeout     = 300
function_memory      = "512M"
function_min_instances = 0
function_max_instances = 5

# Cloud Storage
bucket_name          = "apolo-preavaluos-pdf"  # Debe ser globalmente único
bucket_location      = "US-SOUTH1"
bucket_storage_class = "STANDARD"
bucket_lifecycle_age = 90

# Firestore
firestore_database_name      = "(default)"
firestore_location           = "nam5"
firestore_collection_ttl_days = 365

# Cloud Workflows
workflow_name        = "apolo-procesamiento-workflow"
workflow_description = "Orquestación del procesamiento de documentos"

# Networking y Seguridad
ingress_settings     = "ALLOW_INTERNAL_ONLY"
enable_vpc_connector = false

# Monitoreo
enable_monitoring    = true
log_retention_days   = 30
enable_tracing       = true

# Labels
labels = {
  managed_by  = "terraform"
  project     = "apolo"
  module      = "procesamiento-inteligente"
  environment = "dev"
  team        = "apolo-dev"
}
