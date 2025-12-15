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
# Cloud Run - Configuración QA
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - QA"

# Imagen Docker desde Artifact Registry
cloudrun_image = "us-south1-docker.pkg.dev/apolo-qa-project/apolo-docker-repo/apolo-procesamiento:latest"

# QA: Recursos intermedios para testing realista
cloudrun_cpu            = "2"
cloudrun_memory         = "1Gi"
cloudrun_timeout        = 450  # 7.5 minutos
cloudrun_min_instances  = 0
cloudrun_max_instances  = 5    # Más que dev, menos que prod

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
firestore_location           = "us-south1"
firestore_collection_ttl_days = 180  # Retención media en QA

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
