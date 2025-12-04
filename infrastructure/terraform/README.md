# Terraform Infrastructure as Code

Infrastructure automation for Apolo document processing service on Google Cloud Platform.

## Overview

This Terraform configuration deploys a complete serverless document processing infrastructure including Cloud Run service, Cloud Storage, Firestore database, and optional Cloud Workflows orchestration.

## Project Structure

```
infrastructure/terraform/
├── main.tf          # Core infrastructure resources
├── variables.tf     # Variable definitions
├── outputs.tf       # Output values for integration
├── providers.tf     # GCP provider configuration
├── README.md        # This file
├── deploy.sh        # Bash deployment script
├── deploy.ps1       # PowerShell deployment script
└── env/
    ├── dev.tfvars       # Development environment
    ├── qa.tfvars        # QA environment
    ├── prod.tfvars      # Production environment
    └── example.tfvars   # Template for custom environments
```

## Resources Managed

### Core Resources
- **Cloud Run Service** - Serverless containerized document processor
- **Cloud Storage Bucket** - PDF document storage with versioning
- **Firestore Database** - NoSQL database for results and idempotency
- **Service Accounts** - Dedicated SAs for Cloud Run and Workflows
- **IAM Bindings** - Least-privilege permission assignments

### Optional Resources
- **Cloud Workflows** - Orchestration layer with retry logic
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

### 2. Review Configuration
Edit the appropriate environment file:
```bash
# For development
vi env/dev.tfvars
```

Required variables:
- `project_id` - Your GCP project ID
- `region` - Deployment region (default: us-south1)
- `environment` - Environment name (dev/qa/prod)

### 3. Plan Deployment
```bash
# Development environment
terraform plan -var-file="env/dev.tfvars"

# Production environment
terraform plan -var-file="env/prod.tfvars"
```

### 4. Apply Configuration
```bash
# Development
terraform apply -var-file="env/dev.tfvars"

# Production (requires approval)
terraform apply -var-file="env/prod.tfvars"
```

### 5. Verify Deployment
```bash
# View outputs
terraform output

# Test service
SERVICE_URL=$(terraform output -raw service_url)
curl -X POST $SERVICE_URL \
  -H "Content-Type: application/json" \
  -d '{"folder_prefix": "test/"}'
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
- Min instances: 0
- Max instances: 10
- Memory: 512MB
- Allow unauthenticated: true
- No monitoring alerts

### QA Environment
```bash
terraform plan -var-file="env/qa.tfvars"
terraform apply -var-file="env/qa.tfvars"
```

**QA Configuration:**
- Min instances: 0
- Max instances: 50
- Memory: 1GB
- Allow unauthenticated: false
- Basic monitoring

### Production Environment
```bash
terraform plan -var-file="env/prod.tfvars"
terraform apply -var-file="env/prod.tfvars"
```

**Production Configuration:**
- Min instances: 1 (always warm)
- Max instances: 1000
- Memory: 2GB
- Allow unauthenticated: false
- Full monitoring and alerting
- Budget alerts enabled

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
| `bucket_name` | GCS bucket name | `{project_id}-preavaluos-pdf` |
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
| `service_url` | Cloud Run service endpoint |
| `service_name` | Name of deployed service |
| `bucket_name` | GCS bucket for PDFs |
| `firestore_database` | Firestore database name |
| `service_account_email` | Service account email |
| `workflow_name` | Cloud Workflows name (if enabled) |

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
vi env/dev.tfvars

# Plan changes
terraform plan -var-file="env/dev.tfvars"

# Apply changes
terraform apply -var-file="env/dev.tfvars"
```

### Update Container Image
```bash
# Build new image
gcloud builds submit --tag gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v2.0

# Update variable or main.tf with new image
# Apply changes
terraform apply -var-file="env/dev.tfvars"
```

### Rollback Changes
```bash
# Revert to previous state
terraform apply -var-file="env/dev.tfvars" -auto-approve

# Or use Git to revert changes
git revert HEAD
terraform apply -var-file="env/dev.tfvars"
```

## Destroying Resources

### Destroy Specific Environment
```bash
# Review what will be destroyed
terraform plan -destroy -var-file="env/dev.tfvars"

# Destroy
terraform destroy -var-file="env/dev.tfvars"
```

### Destroy with Target
```bash
# Destroy only Cloud Run service
terraform destroy -target=google_cloud_run_service.processor \
  -var-file="env/dev.tfvars"
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
terraform apply -var-file="env/dev.tfvars"

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
        run: terraform plan -var-file="env/prod.tfvars"
        working-directory: infrastructure/terraform
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -var-file="env/prod.tfvars" -auto-approve
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
terraform plan -var-file="env/dev.tfvars" -out=dev.tfplan

# Apply
terraform apply "dev.tfplan"

# Verify
terraform show
```

### QA
```bash
terraform plan -var-file="env/qa.tfvars" -out=qa.tfplan
terraform apply "qa.tfplan"
```

### Production
```bash
# IMPORTANTE: Revisar plan cuidadosamente antes de aplicar
terraform plan -var-file="env/prod.tfvars" -out=prod.tfplan

# Aplicar solo después de aprobación
terraform apply "prod.tfplan"
```

## 🔐 Variables Requeridas

Debes configurar estas variables en tus archivos `.tfvars`:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `project_id` | ID del proyecto GCP | `apolo-dev-project` |
| `region` | Región GCP | `us-south1` |
| `environment` | Ambiente | `dev`, `qa`, `prod` |
| `bucket_name` | Nombre base del bucket | `apolo-preavaluos-pdf` |

## 📊 Outputs Importantes

Después del despliegue, puedes obtener:

```bash
# URL de la Cloud Function
terraform output function_url

# Nombre del bucket de PDFs
terraform output pdf_bucket_name

# Comando para testear
terraform output curl_test_command

# Comando para ejecutar workflow
terraform output workflow_execution_command

# URLs de monitoreo
terraform output monitoring_urls
```

## 🧪 Testing Post-Despliegue

### Test Manual de Cloud Function

```bash
# Obtener el comando de test
CURL_CMD=$(terraform output -raw curl_test_command)

# Ejecutar
eval "$CURL_CMD"
```

### Test de Workflow

```bash
# Obtener comando
WF_CMD=$(terraform output -raw workflow_execution_command)

# Ejecutar
eval "$WF_CMD"
```

## 🔄 Workflow de Desarrollo

### 1. Hacer Cambios al Código
```bash
# Editar apolo_procesamiento_inteligente.py
# Editar requirements.txt si es necesario
```

### 2. Actualizar Infraestructura
```bash
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

### 3. Verificar Deployment
```bash
# Ver logs en tiempo real
gcloud functions logs read $(terraform output -raw function_name) \
  --region=$(terraform output -raw region) \
  --limit=50
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
- [Cloud Functions Documentation](https://cloud.google.com/functions/docs)
- [Cloud Workflows Documentation](https://cloud.google.com/workflows/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)

## 🔗 Referencias Internas

- Código fuente: `../../apolo_procesamiento_inteligente.py`
- Requirements: `../../requirements.txt`
- Workflow definition: `../../workflow.yaml`
- Main README: `../../README.md`

## 📞 Soporte

Para problemas o preguntas:
- Revisar logs en Cloud Console
- Verificar IAM permissions
- Consultar documentación del proyecto
