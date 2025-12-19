# Apolo Procesamiento Inteligente - Preavalúo

Microservicio serverless para procesamiento inteligente de documentos financieros PDF/A en Google Cloud Platform.

## 📋 Descripción

Este microservicio pertenece al módulo de preavalúos Apolo y ejecuta el procesamiento inteligente por carpeta de documentos financieros. Se activa automáticamente cuando se sube un archivo **IS_READY** a una carpeta en Cloud Storage, procesando todos los PDFs en esa carpeta en paralelo usando Document AI para clasificación y extracción estructurada.

### ✨ Características Principales
- **Activación automática**: Trigger por Eventarc al detectar archivo `IS_READY` (case-insensitive)
- **Procesamiento por carpeta**: Procesa TODOS los PDFs en la carpeta donde se detecta `IS_READY`
- **Procesamiento paralelo**: Múltiples documentos simultáneamente (max 8 concurrentes)
- **Exclusión de archivos vacíos**: El archivo `IS_READY` se excluye automáticamente
- **Idempotencia completa**: Por generación de GCS y estado de carpeta
- **Persistencia trazable**: Esquema jerárquico en Firestore
- **Manejo de errores**: Reintentos con backoff exponencial y DLQ
- **Observabilidad**: Logs estructurados en Cloud Logging

## 🏗️ Arquitectura

- **Runtime**: Python 3.11 en Cloud Run
- **Región**: us-south1
- **Trigger**: Eventarc (GCS object.finalize)
- **Procesamiento**: Document AI Classifier + Extractor
- **Almacenamiento**: Firestore (folios/documentos/extracciones)
- **Mensajería**: Pub/Sub DLQ para errores

## 🚀 Inicio Rápido

### Activación del Servicio

1. **Sube archivos PDF a una carpeta en el bucket**:
   ```bash
   gsutil cp documento1.pdf gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
   gsutil cp documento2.pdf gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
   ```

2. **Sube un archivo IS_READY (sin extensión, vacío) para activar el procesamiento**:
   ```bash
   echo -n "" > IS_READY
   gsutil cp IS_READY gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
   ```

3. **El microservicio se activa automáticamente**:
   - Detecta el archivo `IS_READY` (mayúsculas/minúsculas - case-insensitive)
   - Identifica la carpeta `MI-CARPETA`
   - Procesa TODOS los PDFs en paralelo
   - Excluye el archivo `IS_READY` (está vacío, solo es trigger)

### Despliegue en Cloud Run

**Desde Cloud Shell** (recomendado):
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./update_code.sh
```

**Primera vez (despliegue completo)**:
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./deploy.sh
```

Más detalles en [Guía de Inicio Rápido](Documentation/QUICKSTART.md)

## 📁 Estructura del Proyecto

```
apolo_procesamiento_inteligente_preavaluo/
├── apolo_procesamiento_inteligente.py    # Código principal
├── requirements.txt                      # Dependencias Python
├── runtime.txt                          # Versión Python
├── Dockerfile                            # Imagen Cloud Run
├── docker-compose.yml                    # Desarrollo local
├── pyrightconfig.json                    # Configuración Pylance
├── scripts/                              # Scripts de despliegue
│   ├── setup.sh                         # Configuración GCP
│   ├── deploy.sh                        # Despliegue automatizado
│   ├── README.md                        # Guía de scripts
│   └── ...
├── infrastructure/                       # IaC con Terraform
│   └── terraform/
│       ├── main.tf                      # Recursos principales
│       ├── variables.tf                 # Variables
│       └── env/                         # Config por ambiente
├── Documentation/                        # Documentación completa
│   ├── README.md                        # Índice de docs
│   ├── ARCHITECTURE.md                  # Arquitectura detallada
│   ├── DEPLOY_GUIDE.md                  # Guía de despliegue
│   ├── FIRESTORE_SCHEMA.md              # Esquema base de datos
│   └── ...
├── diagrams/                            # Diagramas Mermaid
│   ├── architecture-dataflow.mmd        # Flujo de arquitectura
│   ├── firestore-schema.mmd             # Esquema Firestore
│   └── ...
└── README.md                            # Este archivo
```

## 📚 Documentación

- **[Inicio Rápido](Documentation/QUICKSTART.md)**: Configuración y despliegue paso a paso
- **[Arquitectura](Documentation/ARCHITECTURE.md)**: Diseño del sistema y componentes
- **[Esquema Firestore](Documentation/FIRESTORE_SCHEMA.md)**: Estructura de datos
- **[Guía de Despliegue](Documentation/DEPLOY_GUIDE.md)**: Deployment detallado
- **[Scripts](scripts/README.md)**: Uso de scripts de automatización
- **[Diagramas](diagrams/README.md)**: Visualizaciones del sistema

## 🔧 Requisitos

- **Python**: 3.11
- **GCP**: Proyecto con billing habilitado
- **APIs**: Cloud Run, Document AI, Firestore, Cloud Storage, Eventarc, Pub/Sub
- **Herramientas**: Docker, gcloud CLI (opcional para desarrollo local)

## 🏷️ Estado del Proyecto

| Componente | Estado | Notas |
|------------|--------|-------|
| **Código Python** | ✅ Completo | Idempotencia, logs estructurados, procesamiento paralelo, detección case-insensitive IS_READY |
| **Docker** | ✅ Completo | Imagen optimizada para Cloud Run |
| **Terraform** | ✅ Completo | Infraestructura en us-south1 |
| **Scripts Cloud Shell** | ✅ Completo | `deploy.sh` y `update_code.sh` con skip-tests |
| **Documentación** | ✅ Actualizada | Incluye flujo IS_READY y cambios recientes (2025-12-19) |
| **Diagramas** | ✅ Completo | Esquemas actualizados |
| **Pruebas** | ✅ Disponible | `test_uuid_processing.sh` en Cloud Shell |
| **Firestore** | ⏳ Pendiente | Inicializar en console.cloud.google.com |

## 🤝 Contribución

1. Revisar [Documentación](Documentation/) para entender la arquitectura
2. Seguir [Guía de Despliegue](Documentation/DEPLOY_GUIDE.md) para desarrollo
3. Usar scripts en `scripts/` para despliegue consistente

## 📄 Licencia

Este proyecto es parte del sistema Apolo de procesamiento de preavalúos.

---

**Última actualización**: Diciembre 19, 2025  
**Versión**: 2.1.0  
**Cambios recientes**: 
- ✅ Detección case-insensitive de archivo IS_READY
- ✅ Exclusión automática del archivo IS_READY del procesamiento
- ✅ Skip-tests en actualizaciones de código
- 📋 Ver [CHANGELOG_RECENT.md](Documentation/CHANGELOG_RECENT.md) para detalles

**Región**: us-south1
└── requirements.txt          # Python dependencies
```

## Resources Managed

### Core Resources
- **Cloud Run Service** - Serverless containerized microservice
- **Artifact Registry** - Docker image repository
- **Eventarc Trigger** - GCS event-driven activation (object.finalize)
- **Document AI Processors** - Classifier and Form Extractor
- **Cloud Storage Bucket** - PDF document storage with versioning
- **Firestore Database** - NoSQL database for results and idempotency
- **Pub/Sub Topic** - Dead Letter Queue for failed documents
- **Service Account** - Dedicated SA for Cloud Run
- **IAM Bindings** - Least-privilege permission assignments

### Optional Resources
- **Log Sinks** - Centralized log aggregation
- **Monitoring Alerts** - Production alerting (prod only)
- **VPC Connector** - Private networking (if needed)

## Prerequisites

### 1. Install Required Tools
```bash
# Terraform (v1.5+)
terraform --version

# Google Cloud SDK
gcloud --version

# Verify authentication
gcloud auth list
```

### 2. Authenticate with GCP
```bash
# Login with user account
gcloud auth application-default login

# Set default project
gcloud config set project YOUR_PROJECT_ID

# Verify project
gcloud config get-value project
```

### 3. Enable Required APIs
```bash
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  iam.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  firestore.googleapis.com
```

### 4. Create Terraform State Bucket
```bash
# Create bucket for remote state
gsutil mb -p YOUR_PROJECT_ID -l us-south1 gs://apolo-tf-state-bucket

# Enable versioning
gsutil versioning set on gs://apolo-tf-state-bucket

# Set lifecycle policy
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"numNewerVersions": 5}
    }]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://apolo-tf-state-bucket
```


## Quick Start

### 1. Initialize Terraform
```bash
cd infrastructure/terraform
terraform init
```

### 2. Build and Push Docker Image
```bash
# Usar Cloud Build desde Google Cloud Shell
cd scripts
./deploy.sh dev TU_PROJECT_ID

# El script automáticamente construye y sube la imagen
```

### 3. Review Configuration
Edit the appropriate environment file:
```bash
# For development
vi env/dev.tfvars
```

Required variables:
- `project_id` - Your GCP project ID
- `region` - Deployment region (default: us-south1)
- `environment` - Environment name (dev/qa/prod)
- `cloudrun_image` - Docker image URL from Artifact Registry

### 4. Plan Deployment
```bash
# Development environment
terraform plan -var-file="env/dev.tfvars"

# Production environment
terraform plan -var-file="env/prod.tfvars"
```

### 5. Apply Configuration
```bash
# Development
terraform apply -var-file="env/dev.tfvars"

# Production (requires approval)
terraform apply -var-file="env/prod.tfvars"
```

### 6. Verify Deployment
```bash
# View outputs
terraform output

# Test by uploading is_ready file to GCS
# 1. Upload test PDFs to: gs://bucket-name/TEST-001/*.pdf
# 2. Upload trigger file: gs://bucket-name/TEST-001/is_ready
# 3. Check Firestore for results in: folios/TEST-001/documentos/

# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit=50
```

## Environment-Specific Deployments

### Development Environment
```bash
# Plan changes
terraform plan -var-file="env/dev.tfvars"

# Apply
terraform apply -var-file="env/dev.tfvars" -auto-approve

# View outputs
terraform output
```

**Dev Configuration:**
- CPU: 1
- Memory: 512Mi
- Min instances: 0
- Max instances: 3
- Timeout: 300s (5 min)
- Ingress: Internal only

### QA Environment
```bash
terraform plan -var-file="env/qa.tfvars"
terraform apply -var-file="env/qa.tfvars"
```

**QA Configuration:**
- CPU: 2
- Memory: 1Gi
- Min instances: 0
- Max instances: 5
- Timeout: 450s (7.5 min)
- Ingress: Internal only

### Production Environment
```bash
terraform plan -var-file="env/prod.tfvars"
terraform apply -var-file="env/prod.tfvars"
```

**Production Configuration:**
- CPU: 2
- Memory: 2Gi
- Min instances: 1 (always warm)
- Max instances: 10
- Timeout: 540s (9 min)
- Ingress: Internal only
- Full monitoring and alerting

## Important Variables

### Required Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | GCP Project ID | `apolo-prod-12345` |
| `region` | GCP region | `us-south1` |
| `environment` | Environment name | `dev`, `qa`, `prod` |

### Optional Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `service_name` | Cloud Run service name | `apolo-procesamiento-inteligente` |
| `bucket_name` | GCS bucket name | `apolo-preavaluos-pdf-dev` |
| `firestore_database` | Firestore database name | `apolo-preavaluos-{env}` |
| `container_image` | Container image URL | Latest from GCR |
| `memory` | Service memory allocation | `1Gi` |
| `timeout` | Request timeout | `300s` |
| `max_instances` | Max service instances | `100` |
| `min_instances` | Min service instances | `0` |

## Outputs

After successful deployment, Terraform provides:

```bash
terraform output
```

| Output | Description |
|--------|-------------|
| `cloudrun_service_url` | Cloud Run service endpoint |
| `cloudrun_service_name` | Name of deployed service |
| `pdf_bucket_name` | GCS bucket for PDFs |
| `firestore_database_name` | Firestore database name |
| `artifact_registry_repo` | Docker image repository |
| `eventarc_trigger_name` | Eventarc trigger for GCS events |
| `classifier_processor_id` | Document AI classifier ID |
| `extractor_processor_id` | Document AI extractor ID |

## State Management

### Remote State Configuration
Edit `providers.tf` to configure remote state:

```hcl
terraform {
  backend "gcs" {
    bucket = "apolo-tf-state-bucket"
    prefix = "terraform/state"
  }
}
```

### State Commands
```bash
# List resources in state
terraform state list

# Show specific resource
terraform state show google_cloud_run_service.processor

# Move resource in state
terraform state mv SOURCE DESTINATION

# Remove resource from state (doesn't delete)
terraform state rm google_cloud_run_service.processor
```

## Updating Infrastructure

### Update Service Configuration
```bash
# Modify variables in env file
vi variables+dev.tfvars

# Plan changes
terraform plan -var-file="variables+dev.tfvars"

# Apply changes
terraform apply -var-file="variables+dev.tfvars"
```

### Update Container Image
```bash
# Build new image
gcloud builds submit --tag gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v2.0

# Update variable or main.tf with new image
# Apply changes
terraform apply -var-file="variables+dev.tfvars"
```

### Rollback Changes
```bash
# Revert to previous state
terraform apply -var-file="variables+dev.tfvars" -auto-approve

# Or use Git to revert changes
git revert HEAD
terraform apply -var-file="variables+dev.tfvars"
```

## Destroying Resources

### Destroy Specific Environment
```bash
# Review what will be destroyed
terraform plan -destroy -var-file="variables+dev.tfvars"

# Destroy
terraform destroy -var-file="variables+dev.tfvars"
```

### Destroy with Target
```bash
# Destroy only Cloud Run service
terraform destroy -target=google_cloud_run_service.processor \
  -var-file="variables+dev.tfvars"
```

### Safety Considerations
⚠️ **Before destroying:**
- Backup Firestore data
- Export GCS bucket contents
- Notify stakeholders
- Disable traffic routing

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
```bash
# Re-authenticate
gcloud auth application-default login

# Verify project
gcloud config get-value project
```

#### 2. API Not Enabled
```bash
# Enable required API
gcloud services enable SERVICE_NAME.googleapis.com
```

#### 3. Permission Denied
```bash
# Check your permissions
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:user:YOUR_EMAIL"
```

#### 4. State Lock Errors
```bash
# Force unlock (use carefully)
terraform force-unlock LOCK_ID
```

#### 5. Resource Already Exists
```bash
# Import existing resource
terraform import google_cloud_run_service.processor \
  projects/PROJECT_ID/locations/REGION/services/SERVICE_NAME
```

### Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply -var-file="variables+dev.tfvars"

# Disable debug logging
unset TF_LOG
```

## Best Practices

### 1. Use Workspaces for Environments
```bash
# Create workspace
terraform workspace new dev

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select dev
```

### 2. Format Code
```bash
terraform fmt -recursive
```

### 3. Validate Configuration
```bash
terraform validate
```

### 4. Generate Documentation
```bash
# Using terraform-docs
terraform-docs markdown table . > TERRAFORM_DOCS.md
```

### 5. Use Variables Files
Never hardcode values - use `.tfvars` files for all environments.

### 6. Enable State Locking
Always use remote backend with locking (GCS supports this automatically).

### 7. Tag Resources
Add labels to all resources for cost tracking and organization:
```hcl
labels = {
  environment = var.environment
  managed_by  = "terraform"
  project     = "apolo-document-processing"
}
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Terraform Deploy
on:
  push:
    branches: [main]
    paths: ['infrastructure/terraform/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: hashicorp/setup-terraform@v1
      
      - name: Terraform Init
        run: terraform init
        working-directory: infrastructure/terraform
      
      - name: Terraform Plan
        run: terraform plan -var-file="variables.tfvars"
        working-directory: infrastructure/terraform
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -var-file="variables.tfvars" -auto-approve
        working-directory: infrastructure/terraform
```

## Security Considerations

1. **Sensitive Variables** - Use environment variables or secret managers
2. **State File Security** - Restrict access to state bucket
3. **Service Account Permissions** - Follow least privilege principle
4. **Enable Encryption** - Use customer-managed encryption keys (optional)
5. **Audit Logging** - Enable Cloud Audit Logs for all resources

## Cost Optimization

### Strategies Implemented
- Scale to zero when idle (min_instances=0 in dev/qa)
- Efficient container images (slim base)
- Lifecycle policies on GCS
- Appropriate instance sizing per environment

### Cost Estimation
```bash
# Use Google Cloud Pricing Calculator
# Typical monthly costs (dev environment):
# - Cloud Run: $5-20 (minimal traffic)
# - Cloud Storage: $1-5 (few GBs)
# - Firestore: $1-10 (reads/writes)
# Total: ~$10-40/month for dev
```

## Support

For issues or questions:
1. Check [Architecture Documentation](../../Documentation/ARCHITECTURE.md)
2. Review [GCP Commands Guide](../../Documentation/GCP_COMMANDS.md)
3. See [Deployment Checklist](../../Documentation/DEPLOYMENT_CHECKLIST.md)
4. Contact DevOps team

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-04 | Initial Terraform configuration |

---

**Maintained by**: Apolo Solutions DevOps Team  
**Last Updated**: December 2025
terraform plan -var-file="variables+dev.tfvars" -out=dev.tfplan

# Apply
terraform apply "dev.tfplan"

# Verify
terraform show
```

### QA
```bash
terraform plan -var-file="variables+qa.tfvars" -out=qa.tfplan
terraform apply "qa.tfplan"
```

### Production
```bash
# IMPORTANTE: Revisar plan cuidadosamente antes de aplicar
terraform plan -var-file="variables.tfvars" -out=prod.tfplan

# Aplicar solo después de aprobación
terraform apply "prod.tfplan"
```

## 🔐 Variables Requeridas

Debes configurar estas variables en tus archivos `.tfvars`:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `project_id` | ID del proyecto GCP | `apolo-dev-478018` |
| `region` | Región GCP | `us-south1` |
| `environment` | Ambiente | `dev`, `qa`, `prod` |
| `bucket_name` | Nombre base del bucket | `apolo-preavaluos-pdf-dev` |

## 📊 Outputs Importantes

Después del despliegue, puedes obtener:

```bash
# URL del Cloud Run service
terraform output cloudrun_service_url

# Nombre del bucket de PDFs
terraform output pdf_bucket_name

# Repository de Artifact Registry
terraform output artifact_registry_repo

# Trigger de Eventarc
terraform output eventarc_trigger_name

# Document AI processors
terraform output classifier_processor_id
terraform output extractor_processor_id

# URLs de monitoreo
terraform output monitoring_urls
```

## 🧪 Testing Post-Despliegue

### Test de Procesamiento con Eventarc

```bash
# 1. Subir PDFs de prueba a una carpeta
gsutil cp test.pdf gs://$(terraform output -raw pdf_bucket_name)/TEST-001/

# 2. Crear archivo is_ready para activar el procesamiento
echo "" | gsutil cp - gs://$(terraform output -raw pdf_bucket_name)/TEST-001/is_ready

# 3. Ver logs del Cloud Run service
gcloud logging read "resource.type=cloud_run_revision" --limit=50 --format=json

# 4. Verificar resultados en Firestore
gcloud firestore documents list folios/TEST-001/documentos
```

### Test Manual del Cloud Run Service (opcional)

```bash
# Obtener el comando de test
CURL_CMD=$(terraform output -raw curl_test_command)

# Ejecutar (requiere autenticación)
eval "$CURL_CMD"
```

## 🔄 Workflow de Desarrollo

### 1. Hacer Cambios al Código
```bash
# Editar apolo_procesamiento_inteligente.py
# Editar requirements.txt si es necesario
# Editar Dockerfile si es necesario
```

### 2. Build y Push de Nueva Imagen
```bash
# Desde Google Cloud Shell
cd scripts
./deploy.sh dev TU_PROJECT_ID

# El despliegue completo incluye build, push y deploy
```

### 3. Deploy con Terraform
```bash
cd infrastructure/terraform
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

### 4. Verificar Deployment
```bash
# Ver logs del Cloud Run service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(terraform output -raw cloudrun_service_name)" \
  --limit=50 \
  --format=json
```

## 🛡️ Mejores Prácticas

### State Management
- ✅ **Backend remoto en GCS** - State guardado en Cloud Storage
- ✅ **State locking** - Previene conflictos en equipo
- ✅ **State por ambiente** - Dev, QA y Prod separados

### Seguridad
- ✅ **Service Accounts dedicadas** - Mínimos privilegios
- ✅ **IAM roles específicos** - No usar Owner
- ✅ **Ingress interno** - Sin exposición pública
- ✅ **Secrets en Secret Manager** - Cuando sea necesario

### Versionamiento
- ✅ **Pin Terraform version** - `1.5.7`
- ✅ **Pin provider versions** - `~> 7.12.0`
- ✅ **Git tags para releases** - v1.0.0, v1.1.0, etc.

## 🐛 Troubleshooting

### Error: "Backend configuration changed"
```bash
terraform init -reconfigure
```

### Error: "Resource already exists"
```bash
# Importar recurso existente
terraform import google_storage_bucket.pdf_bucket bucket-name
```

### Error: "APIs not enabled"
```bash
# Habilitar APIs manualmente
gcloud services enable cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  firestore.googleapis.com \
  --project=YOUR_PROJECT_ID
```

## 📚 Recursos Adicionales

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Eventarc Documentation](https://cloud.google.com/eventarc/docs)
- [Document AI Documentation](https://cloud.google.com/document-ai/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)

## 🔗 Referencias Internas

- Código fuente: `../../apolo_procesamiento_inteligente.py`
- Requirements: `../../requirements.txt`
- Dockerfile: `../../Dockerfile`
- Scripts de despliegue: [scripts/README.md](../../scripts/README.md) ⭐ **Actualizado**

## 📞 Soporte

Para problemas o preguntas:
- Revisar logs en Cloud Console
- Verificar IAM permissions
- Consultar documentación del proyecto
