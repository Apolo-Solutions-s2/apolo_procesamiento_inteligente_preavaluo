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
# Variables de Cloud Run
# ─────────────────────────────────────────────────────────────

variable "function_name" {
  description = "Nombre del Cloud Run service"
  type        = string
  default     = "apolo-procesamiento-inteligente"
}

variable "function_description" {
  description = "Descripción del Cloud Run service"
  type        = string
  default     = "Procesamiento inteligente de documentos financieros para preavalúos"
}

variable "cloudrun_image" {
  description = "Imagen Docker para Cloud Run (usar Artifact Registry o Container Registry)"
  type        = string
}

variable "cloudrun_cpu" {
  description = "CPUs asignadas al contenedor"
  type        = string
  default     = "2"
}

variable "cloudrun_memory" {
  description = "Memoria asignada al contenedor"
  type        = string
  default     = "1Gi"
}

variable "cloudrun_timeout" {
  description = "Timeout del servicio en segundos"
  type        = number
  default     = 540
}

variable "cloudrun_min_instances" {
  description = "Número mínimo de instancias"
  type        = number
  default     = 0
}

variable "cloudrun_max_instances" {
  description = "Número máximo de instancias"
  type        = number
  default     = 10
}

# Variables legacy mantenidas para compatibilidad
variable "function_runtime" {
  description = "Runtime (legacy - no usado en Cloud Run)"
  type        = string
  default     = "python311"
}

variable "function_entry_point" {
  description = "Entry point (legacy - no usado en Cloud Run)"
  type        = string
  default     = "process_folder_on_ready"
}

variable "function_timeout" {
  description = "Timeout (legacy - usar cloudrun_timeout)"
  type        = number
  default     = 540
}

variable "function_memory" {
  description = "Memoria (legacy - usar cloudrun_memory)"
  type        = string
  default     = "1Gi"
}

variable "function_min_instances" {
  description = "Min instances (legacy - usar cloudrun_min_instances)"
  type        = number
  default     = 0
}

variable "function_max_instances" {
  description = "Max instances (legacy - usar cloudrun_max_instances)"
  type        = number
  default     = 10
}

variable "function_source_dir" {
  description = "Source dir (legacy - no usado en Cloud Run)"
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
  default     = "us-south1"
}

variable "firestore_collection_ttl_days" {
  description = "Días de retención de documentos en Firestore"
  type        = number
  default     = 365
}

# ─────────────────────────────────────────────────────────────
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
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "iam.googleapis.com",
    "documentai.googleapis.com",
    "pubsub.googleapis.com",
    "eventarc.googleapis.com",
  ]
}

# ─────────────────────────────────────────────────────────────
# Variables de Document AI
# ─────────────────────────────────────────────────────────────

variable "documentai_classifier_type" {
  description = "Tipo de Document AI Classifier processor"
  type        = string
  default     = "DOCUMENT_CLASSIFIER"
}

variable "documentai_extractor_type" {
  description = "Tipo de Document AI Extractor processor"
  type        = string
  default     = "FORM_PARSER_PROCESSOR"
}

# ─────────────────────────────────────────────────────────────
# Variables de Pub/Sub (DLQ)
# ─────────────────────────────────────────────────────────────

variable "dlq_topic_name" {
  description = "Nombre del Pub/Sub topic para Dead Letter Queue"
  type        = string
  default     = "apolo-preavaluo-dlq"
}

variable "dlq_retention_days" {
  description = "Días de retención de mensajes en DLQ"
  type        = number
  default     = 7
}

# ─────────────────────────────────────────────────────────────
# Variables de Eventarc
# ─────────────────────────────────────────────────────────────

variable "enable_eventarc" {
  description = "Habilitar Eventarc trigger para GCS"
  type        = bool
  default     = true
}

variable "eventarc_trigger_name" {
  description = "Nombre del Eventarc trigger"
  type        = string
  default     = "apolo-gcs-trigger"
}
