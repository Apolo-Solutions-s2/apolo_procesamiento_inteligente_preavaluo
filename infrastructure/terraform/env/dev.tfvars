# ============================================================================
# Terraform Variables - Development Environment
# ============================================================================
# Configuración específica para el ambiente de desarrollo
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Proyecto y Región
# ─────────────────────────────────────────────────────────────

project_id  = "apolo-dev-478018"
region      = "us-south1"
zone        = "us-south1-a"
environment = "dev"

# ─────────────────────────────────────────────────────────────
# Cloud Run - Configuración Dev
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - DEV"

# Imagen Docker desde Artifact Registry
cloudrun_image = "us-south1-docker.pkg.dev/apolo-dev-478018/apolo-docker-repo/apolo-procesamiento:latest"

# Dev: Recursos reducidos
cloudrun_cpu            = "1"
cloudrun_memory         = "512Mi"
cloudrun_timeout        = 300  # 5 minutos
cloudrun_min_instances  = 0    # Sin instancias permanentes
cloudrun_max_instances  = 3    # Límite bajo para dev

# ─────────────────────────────────────────────────────────────
# Cloud Storage
# ─────────────────────────────────────────────────────────────

bucket_name          = "apolo-preavaluos-pdf-dev"
bucket_location      = "US-SOUTH1"
bucket_storage_class = "STANDARD"
bucket_lifecycle_age = 30  # Mover a nearline después de 30 días en dev

# ─────────────────────────────────────────────────────────────
# Firestore
# ─────────────────────────────────────────────────────────────

firestore_database_name      = "(default)"
firestore_location           = "us-south1"
firestore_collection_ttl_days = 90  # Retención corta en dev

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
