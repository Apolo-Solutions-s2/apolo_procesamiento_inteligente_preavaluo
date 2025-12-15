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
# Cloud Run - Configuración Production
# ─────────────────────────────────────────────────────────────

function_name        = "apolo-procesamiento-inteligente"
function_description = "Procesamiento inteligente de documentos financieros - PRODUCTION"

# Imagen Docker desde Artifact Registry
cloudrun_image = "us-south1-docker.pkg.dev/apolo-prod-project/apolo-docker-repo/apolo-procesamiento:latest"

# Prod: Máximos recursos para confiabilidad
cloudrun_cpu            = "2"
cloudrun_memory         = "2Gi"  # 2GB para procesamiento pesado
cloudrun_timeout        = 540    # 9 minutos (máximo)
cloudrun_min_instances  = 1      # Al menos 1 instancia caliente
cloudrun_max_instances  = 10     # Escalado hasta 10 instancias

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
firestore_location           = "us-south1"
firestore_collection_ttl_days = 365  # Retención completa de 1 año

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
