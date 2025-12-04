# ============================================================================
# Terraform Variables
# ============================================================================
# Variables para configurar la infraestructura del microservicio
# de procesamiento inteligente de documentos financieros
# ============================================================================

# ─────────────────────────────────────────────────────────────
# Variables Generales de Proyecto
# ─────────────────────────────────────────────────────────────

variable "project_id" {
  description = "ID del proyecto de Google Cloud Platform"
  type        = string
}

variable "region" {
  description = "Región principal de GCP donde se desplegarán los recursos"
  type        = string
  default     = "us-south1"
}

variable "zone" {
  description = "Zona específica dentro de la región"
  type        = string
  default     = "us-south1-a"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, qa, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El ambiente debe ser dev, qa o prod."
  }
}

# ─────────────────────────────────────────────────────────────
# Variables de Cloud Function
# ─────────────────────────────────────────────────────────────

variable "function_name" {
  description = "Nombre de la Cloud Function"
  type        = string
  default     = "apolo-procesamiento-inteligente"
}

variable "function_description" {
  description = "Descripción de la Cloud Function"
  type        = string
  default     = "Procesamiento inteligente de documentos financieros para preavalúos"
}

variable "function_runtime" {
  description = "Runtime de la Cloud Function"
  type        = string
  default     = "python311"
}

variable "function_entry_point" {
  description = "Punto de entrada de la función"
  type        = string
  default     = "document_processor"
}

variable "function_timeout" {
  description = "Timeout de la función en segundos"
  type        = number
  default     = 540
}

variable "function_memory" {
  description = "Memoria asignada a la función (en MB)"
  type        = string
  default     = "512M"
}

variable "function_min_instances" {
  description = "Número mínimo de instancias"
  type        = number
  default     = 0
}

variable "function_max_instances" {
  description = "Número máximo de instancias"
  type        = number
  default     = 10
}

variable "function_source_dir" {
  description = "Directorio con el código fuente de la función"
  type        = string
  default     = "../../"
}

# ─────────────────────────────────────────────────────────────
# Variables de Cloud Storage
# ─────────────────────────────────────────────────────────────

variable "bucket_name" {
  description = "Nombre del bucket de GCS para almacenar PDFs"
  type        = string
}

variable "bucket_location" {
  description = "Ubicación del bucket de GCS"
  type        = string
  default     = "US-SOUTH1"
}

variable "bucket_storage_class" {
  description = "Clase de almacenamiento del bucket"
  type        = string
  default     = "STANDARD"
}

variable "bucket_lifecycle_age" {
  description = "Días antes de mover archivos a storage class inferior"
  type        = number
  default     = 90
}

# ─────────────────────────────────────────────────────────────
# Variables de Firestore
# ─────────────────────────────────────────────────────────────

variable "firestore_database_name" {
  description = "Nombre de la base de datos Firestore"
  type        = string
  default     = "(default)"
}

variable "firestore_location" {
  description = "Ubicación de Firestore"
  type        = string
  default     = "nam5"
}

variable "firestore_collection_ttl_days" {
  description = "Días de retención de documentos en Firestore"
  type        = number
  default     = 365
}

# ─────────────────────────────────────────────────────────────
# Variables de Cloud Workflows
# ─────────────────────────────────────────────────────────────

variable "workflow_name" {
  description = "Nombre del Cloud Workflow"
  type        = string
  default     = "apolo-procesamiento-workflow"
}

variable "workflow_description" {
  description = "Descripción del Cloud Workflow"
  type        = string
  default     = "Orquestación del procesamiento de documentos financieros"
}

variable "workflow_source_file" {
  description = "Archivo fuente del workflow YAML"
  type        = string
  default     = "../../workflow.yaml"
}

# ─────────────────────────────────────────────────────────────
# Variables de Service Account
# ─────────────────────────────────────────────────────────────

variable "service_account_name" {
  description = "Nombre de la Service Account"
  type        = string
  default     = "apolo-procesamiento-sa"
}

variable "service_account_display_name" {
  description = "Nombre para mostrar de la Service Account"
  type        = string
  default     = "Apolo Procesamiento Inteligente Service Account"
}

# ─────────────────────────────────────────────────────────────
# Variables de Networking y Seguridad
# ─────────────────────────────────────────────────────────────

variable "enable_vpc_connector" {
  description = "Habilitar VPC Connector para la función"
  type        = bool
  default     = false
}

variable "vpc_connector_name" {
  description = "Nombre del VPC Connector"
  type        = string
  default     = "apolo-vpc-connector"
}

variable "ingress_settings" {
  description = "Configuración de ingress para la Cloud Function"
  type        = string
  default     = "ALLOW_INTERNAL_ONLY"
  validation {
    condition     = contains(["ALLOW_ALL", "ALLOW_INTERNAL_ONLY", "ALLOW_INTERNAL_AND_GCLB"], var.ingress_settings)
    error_message = "ingress_settings debe ser ALLOW_ALL, ALLOW_INTERNAL_ONLY o ALLOW_INTERNAL_AND_GCLB."
  }
}

# ─────────────────────────────────────────────────────────────
# Variables de Monitoreo y Logging
# ─────────────────────────────────────────────────────────────

variable "enable_monitoring" {
  description = "Habilitar monitoreo avanzado"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Días de retención de logs"
  type        = number
  default     = 30
}

variable "enable_tracing" {
  description = "Habilitar Cloud Trace"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────
# Variables de Labels y Tags
# ─────────────────────────────────────────────────────────────

variable "labels" {
  description = "Labels para aplicar a todos los recursos"
  type        = map(string)
  default = {
    managed_by = "terraform"
    project    = "apolo"
    module     = "procesamiento-inteligente"
  }
}

# ─────────────────────────────────────────────────────────────
# Variables de APIs Requeridas
# ─────────────────────────────────────────────────────────────

variable "required_apis" {
  description = "APIs de GCP requeridas para el proyecto"
  type        = list(string)
  default = [
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "workflows.googleapis.com",
    "run.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
  ]
}
