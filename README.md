# Apolo - Financial Document Processing Service

Intelligent document processing microservice for financial statement analysis.

## Overview

Cloud Run service that processes PDF financial documents from Google Cloud Storage using a three-stage pipeline:
1. **PDF Validation** - Verifies valid PDF format using magic byte inspection
2. **Classification** - Identifies document type (Income Statement, Balance Sheet, Cash Flow)
3. **Extraction** - Extracts structured financial data fields
4. **Persistence** - Stores results in Firestore with idempotency

## Quick Links

📚 **Documentation**
- [Architecture Overview](Documentation/ARCHITECTURE.md) - System design and data flow
- [Infrastructure Summary](Documentation/INFRASTRUCTURE.md) - Complete infrastructure details
- [Deployment Checklist](Documentation/DEPLOYMENT_CHECKLIST.md) - Pre-deployment verification
- [GCP Commands Reference](Documentation/GCP_COMMANDS.md) - Essential gcloud commands
- [Firestore Schema](Documentation/FIRESTORE_SCHEMA.md) - Database structure
- [Testing Guide](Documentation/TESTING.md) - Test procedures
- [Quick Start](Documentation/QUICKSTART.md) - Get started in 5 minutes

🚀 **Deployment**
- [Terraform IaC](infrastructure/terraform/README.md) - Infrastructure as Code
- [PowerShell Scripts](scripts/powershell/README.md) - Windows deployment
- [Bash Scripts](scripts/bash/README.md) - Linux/Mac deployment

## Technical Specifications

| Component | Technology | Version |
|-----------|-----------|---------|
| **Runtime** | Python | 3.11 |
| **Framework** | Flask + functions-framework | 3.x |
| **Platform** | Cloud Run (Gen 2) | Latest |
| **Region** | us-south1 (Dallas) | - |
| **Storage** | Cloud Storage | - |
| **Database** | Firestore (Native mode) | - |
| **Auth** | Service Account + OIDC | - |

## Architecture

### Deployment Modes

**Mode 1: Direct HTTP Invocation**
```
Client → HTTP POST → Cloud Run → GCS + Firestore
```
✅ Simple integration  
✅ Synchronous responses  
✅ Ideal for development/testing  

**Mode 2: Cloud Workflows Orchestration**
```
Client → Cloud Workflows → OIDC Auth → Cloud Run → GCS + Firestore
```
✅ Complex workflow orchestration  
✅ Automatic retries with backoff  
✅ Production-grade reliability  

### Processing Modes

| Mode | Input | Use Case |
|------|-------|----------|
| **Individual** | Single `gcs_pdf_uri` | Process one document |
| **Batch (List)** | Array of `fileList` | Document AI batch format |
| **Batch (Folder)** | `folder_prefix` | Discover and process all PDFs in folder |

## API Contract

### Request Format

**Individual Document:**
```json
{
  "folioId": "PRE-2025-001",
  "fileId": "balance.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance.pdf",
  "workflow_execution_id": "optional-correlation-id"
}
```

**Batch Processing (Folder):**
```json
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001",
  "extensions": [".pdf"],
  "max_items": 500
}
```

**Batch Processing (File List):**
```json
{
  "runId": "custom-run-id",
  "fileList": [
    {"gcsUri": "gs://bucket/file1.pdf", "file_name": "doc1.pdf"},
    {"gcsUri": "gs://bucket/file2.pdf", "file_name": "doc2.pdf"}
  ]
}
```

### Response Format

**Success (HTTP 200):**
```json
{
  "status": "processed",
  "run_id": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "bucket": "preavaluos-pdf",
  "document_count": 2,
  "processedCount": 2,
  "failedCount": 0,
  "results": [
    {
      "file_name": "balance.pdf",
      "status": "processed",
      "from_cache": false,
      "classification": {
        "documentType": "ESTADO_SITUACION_FINANCIERA",
        "confidence": 0.95,
        "classifierVersion": "v1"
      },
      "extraction": {
        "fields": {
          "ORG_NAME": "Apolo Solutions S.A.",
          "REPORTING_PERIOD": "2024-12-31",
          "CURRENCY": "MXN",
          "line_items": [...]
        },
        "metadata": {...}
      }
    }
  ]
}
```

**Error (HTTP 500):**
```json
{
  "status": "error",
  "run_id": "wf-abc123",
  "error": {
    "stage": "VALIDATION",
    "code": "INVALID_PDF_FORMAT",
    "message": "Invalid PDF header",
    "details": {...},
    "ts_utc": "2025-12-04T10:30:00Z"
  }
}
```

## Document Types

The service classifies financial documents into three categories:

| Type | Description | Spanish Name |
|------|-------------|--------------|
| `ESTADO_RESULTADOS` | Income Statement / Profit & Loss | Estado de Resultados |
| `ESTADO_SITUACION_FINANCIERA` | Balance Sheet | Balance General |
| `ESTADO_FLUJOS_EFECTIVO` | Cash Flow Statement | Estado de Flujos de Efectivo |

### Extracted Fields

Each document type extracts specific structured fields:
- **Common**: Organization name, reporting period, currency, units scale
- **Line Items**: Account names, values, years, section headers, totals
- **Metadata**: Page count, processor version, table references

See [Firestore Schema](Documentation/FIRESTORE_SCHEMA.md) for complete field definitions.

## Idempotency & Caching

### Firestore Structure
```
firestore (database: apolo-preavaluos-dev)
└── runs/
    └── {runId}/
        ├── status, documentCount, processedCount, failedCount
        └── documents/
            └── {docId}/  # SHA-256 hash of folioId:fileId
                ├── classification
                ├── extraction
                └── status
```

### How It Works
1. Generate deterministic `docId` from `folioId:fileId`
2. Check Firestore for existing result
3. If found and completed → return cached result (`from_cache: true`)
4. If not found → process document and persist
5. Lease mechanism prevents concurrent processing (10-minute timeout)

**Benefits:**
- Prevents duplicate processing costs
- Instant responses for re-requested documents
- Complete audit trail
- Safe for retries

## Deployment

### Option 1: Automated Scripts (Recommended)

**PowerShell (Windows):**
```powershell
cd scripts/powershell
.\deploy-complete.ps1
```

**Bash (Linux/Mac/Cloud Shell):**
```bash
cd scripts/bash
./deploy-cloudrun.sh
```

**Features:**
- Enables required APIs
- Creates GCS bucket and Firestore database
- Builds and deploys container
- Runs test suite
- ~5-7 minutes end-to-end

### Option 2: Terraform (Infrastructure as Code)

```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file="env/dev.tfvars"
```

**See:** [Terraform README](infrastructure/terraform/README.md)

### Option 3: Manual gcloud

```bash
# Deploy from source
gcloud run deploy apolo-procesamiento-inteligente \
  --source . \
  --region us-south1 \
  --set-env-vars BUCKET_NAME=preavaluos-pdf,FIRESTORE_DATABASE=apolo-preavaluos-dev

# Or deploy from pre-built image
gcloud run deploy apolo-procesamiento-inteligente \
  --image gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:latest \
  --region us-south1
```

**See:** [GCP Commands Reference](Documentation/GCP_COMMANDS.md)

## Testing

### Quick Test
```bash
SERVICE_URL="https://your-service-url.run.app"

curl -X POST "${SERVICE_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "gcs_pdf_uri": "gs://preavaluos-pdf/test.pdf",
    "folioId": "TEST-001",
    "fileId": "test.pdf"
  }'
```

### Test Suite
```bash
# PowerShell
.\scripts\powershell\test-cloudrun.ps1

# Bash
./scripts/bash/test-cloudrun.sh
```

**See:** [Testing Guide](Documentation/TESTING.md) for comprehensive test scenarios

## Monitoring

### View Logs
```bash
gcloud logging tail "resource.type=cloud_run_revision"
```

### Error Logs Only
```bash
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" --limit 20
```

### Structured Log Format
```json
{
  "event_type": "progress",
  "ts_utc": "2025-12-04T10:30:00Z",
  "run_id": "wf-abc123",
  "step": "CLASSIFY_START",
  "percent": 40,
  "total_files": 10
}
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BUCKET_NAME` | GCS bucket for PDFs | `preavaluos-pdf` |
| `FIRESTORE_DATABASE` | Firestore database name | `apolo-preavaluos-dev` |
| `PORT` | HTTP port | `8080` |
| `PYTHONUNBUFFERED` | Unbuffered output | `1` |

## Security

### Authentication
- **Development**: Allow unauthenticated (for testing)
- **Production**: Require authentication (OIDC or API key)

### Service Account Permissions
- `roles/storage.objectViewer` - Read PDFs from GCS
- `roles/datastore.user` - Read/write Firestore
- `roles/logging.logWriter` - Write logs

### Data Protection
- Encryption at rest (default GCP)
- Encryption in transit (TLS 1.2+)
- No sensitive data in logs
- Non-root container user

## Cost Optimization

### Strategies Implemented
1. **Scale to zero** - No cost when idle (min_instances=0 in dev)
2. **Idempotency** - Prevents duplicate processing
3. **Early validation** - Fails fast before expensive AI calls
4. **Result caching** - Firestore cache reduces reprocessing
5. **Efficient container** - Slim base image reduces cold start costs

### Estimated Costs (Development)
- Cloud Run: $2-5/month
- Cloud Storage: $1-2/month
- Firestore: $0.50-2/month
- **Total: ~$5-10/month** (light usage)

## Troubleshooting

### Service Not Responding
```bash
# Check service status
gcloud run services describe apolo-procesamiento-inteligente --region us-south1

# View recent errors
gcloud logging read "severity>=ERROR" --limit 20
```

### Permission Denied
```bash
# Verify service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:serviceAccount:SA_EMAIL"
```

### Container Build Fails
```bash
# Check build logs
gcloud builds list --limit=1
gcloud builds log BUILD_ID
```

## Project Structure

```
apolo_procesamiento_inteligente_preavaluo/
├── apolo_procesamiento_inteligente.py  # Main service code
├── requirements.txt                     # Python dependencies
├── Dockerfile                           # Container definition
├── runtime.txt                          # Python version
├── workflow.yaml                        # Cloud Workflows config (optional)
├── README.md                            # This file
│
├── Documentation/                       # Complete documentation
│   ├── ARCHITECTURE.md                  # System architecture
│   ├── INFRASTRUCTURE.md                # Infrastructure details
│   ├── DEPLOYMENT_CHECKLIST.md          # Deployment guide
│   ├── GCP_COMMANDS.md                  # Command reference
│   ├── FIRESTORE_SCHEMA.md              # Database schema
│   ├── TESTING.md                       # Testing procedures
│   └── QUICKSTART.md                    # Quick start guide
│
├── scripts/                             # Deployment automation
│   ├── powershell/                      # Windows scripts
│   │   ├── deploy-complete.ps1          # Full deployment
│   │   ├── build-docker.ps1             # Build container
│   │   ├── deploy-cloudrun.ps1          # Deploy service
│   │   └── test-cloudrun.ps1            # Test suite
│   └── bash/                            # Linux/Mac scripts
│       ├── build-docker.sh
│       ├── deploy-cloudrun.sh
│       └── test-cloudrun.sh
│
└── infrastructure/
    └── terraform/                       # Infrastructure as Code
        ├── main.tf                      # Core resources
        ├── variables.tf                 # Variable definitions
        ├── outputs.tf                   # Output values
        ├── providers.tf                 # Provider config
        ├── README.md                    # Terraform guide
        └── env/                         # Environment configs
            ├── dev.tfvars
            ├── qa.tfvars
            └── prod.tfvars
```

## Development

### Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
functions-framework --target=document_processor --debug
```

### Docker Build
```bash
# Build image
docker build -t apolo-procesamiento-inteligente .

# Run locally
docker run -p 8080:8080 \
  -e BUCKET_NAME=preavaluos-pdf \
  -e FIRESTORE_DATABASE=apolo-preavaluos-dev \
  apolo-procesamiento-inteligente
```

## Roadmap

### Current (v1.0) - Simulated Processing
- ✅ PDF validation
- ✅ Simulated classification
- ✅ Simulated extraction
- ✅ Firestore persistence
- ✅ Idempotency
- ✅ Three processing modes

### Next (v1.1) - Document AI Integration
- [ ] Real Document AI Classifier
- [ ] Real Document AI Extractor
- [ ] Custom processor training
- [ ] Confidence thresholds
- [ ] Human review queue

### Future (v2.0) - Advanced Features
- [ ] Multi-region deployment
- [ ] Advanced analytics
- [ ] BigQuery integration
- [ ] Real-time notifications
- [ ] API Gateway

## Support

- **Documentation**: See `Documentation/` folder
- **Issues**: GitHub Issues
- **Questions**: Contact DevOps team

## License

MIT License - See [LICENSE](LICENSE) file

---

**Maintained by**: Apolo Solutions DevOps Team  
**Version**: 1.0.0  
**Last Updated**: December 2025
  "document_count": 2,
  "results": [
    {
      "file_name": "balance_general.pdf",
      "gcs_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
      "classification": {
        "document_type": "BalanceGeneral",
        "confidence": 0.95
      },
      "extraction": {
        "fields": {"Ingresos": 25000.50, "Egresos": 12000.75, "Fecha": "2025-12-01"},
        "metadata": {
          "page_refs": [{"page": 1, "bbox": {"x1": 100, "y1": 200, "x2": 300, "y2": 220}}],
          "processor_version": "sim-v1",
          "decision_path": "SIMULATED"
        }
      },
      "processed_at": "2025-12-04T14:30:00.123456",
      "from_cache": false
    }
  ]
}
```

**Salida (Response JSON) - Error**
```json
{
  "status": "error",
  "run_id": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "bucket": "preavaluos-pdf",
  "folder_prefix": "PRE-2025-001/",
  "document_count": 0,
  "results": [],
  "error": {
    "stage": "VALIDATION",
    "code": "NO_VALID_PDFS",
    "message": "No valid PDF files found.",
    "details": {"invalid_files": [{"file_name": "doc.txt", "error": {...}}]},
    "ts_utc": "2025-12-04T14:30:00Z"
  }
}
```

## 🔄 Idempotencia y Firestore (Document AI)

El microservicio implementa una **estructura jerárquica en Firestore** para organizar resultados de Document AI por corrimiento (run):

### Estructura de Colecciones
```
firestore (database: apolo-preavaluos-dev)
└── runs/
    ├── {runId}/                    # UUID del corrimiento
    │   ├── status: processing | completed | partial_failure
    │   ├── documentCount, processedCount, failedCount
    │   └── documents/              # Subcolección
    │       └── {docId}/            # Hash SHA-256(folioId:fileId)
    │           ├── classification: {...}
    │           └── extraction: {...}
```

### Características Clave
- **Document ID**: Hash SHA-256 de `folioId:fileId` (16 caracteres)
- **Lease Mechanism**: Previene procesamiento concurrente (timeout: 10 minutos)
- **Cache Hit**: Si el documento ya fue procesado, retorna desde Firestore con `from_cache: true`
- **Status Tracking**: `processing` → `completed` | `failed`
- **Contadores Automáticos**: Se actualizan con `firestore.Increment()` (atómico)

### Clasificador Document AI
El sistema soporta **3 tipos de documentos financieros**:
- `ESTADO_RESULTADOS` - Estado de Resultados / Profit & Loss
- `ESTADO_SITUACION_FINANCIERA` - Balance General / Statement of Financial Position
- `ESTADO_FLUJOS_EFECTIVO` - Estado de Flujos de Efectivo / Cash Flow Statement

### Extractores Estructurados
Cada tipo de documento tiene campos específicos extraídos:
- `LINE_ITEM_NAME`, `LINE_ITEM_VALUE`, `COLUMN_YEAR`
- `SECTION_HEADER`, `TOTAL_LABEL`, `CURRENCY`, `UNITS_SCALE`
- `REPORTING_PERIOD`, `ORG_NAME`, `STATEMENT_TITLE`
- Metadata: `processor_version`, `extraction_schema_version`, `page_count`

**Ver esquema completo**: [`docs/FIRESTORE_SCHEMA.md`](docs/FIRESTORE_SCHEMA.md)

**Ejemplo de documento en Firestore:**
```json
{
  "docId": "a1b2c3d4e5f6g7h8",
  "runId": "wf-abc123",
  "folioId": "PRE-2025-001",
  "fileId": "balance_general.pdf",
  "gcsUri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
  "status": "completed",
  
  "classification": {
    "documentType": "ESTADO_SITUACION_FINANCIERA",
    "confidence": 0.985,
    "classifierVersion": "document-ai-classifier-v1"
  },
  
  "extraction": {
    "fields": {
      "ORG_NAME": "Apolo Solutions S.A. de C.V.",
      "REPORTING_PERIOD": "2024-12-31",
      "STATEMENT_TITLE": "Estado de Situación Financiera",
      "line_items": [
        {
          "LINE_ITEM_NAME": "Total Activo",
          "LINE_ITEM_VALUE": 7500000.00,
          "COLUMN_YEAR": "2024",
          "TOTAL_LABEL": "TOTAL"
        }
      ]
    },
    "metadata": {
      "processor_version": "document-ai-v1",
      "extraction_schema_version": "v1.0"
    }
  },
  
  "processedAt": "2025-12-04T14:30:05Z"
}
```
          "page_refs": [{"page": 1, "bbox": {"x1": 100, "y1": 200, "x2": 300, "y2": 220}}],
          "processor_version": "sim-v1",
          "decision_path": "SIMULATED"
        }
      },
      "processed_at": "2025-12-03T14:30:00.123456"
    }
  ]
}
```

**Tipos de Documentos Soportados**
- `EstadoDeResultados` - Documento financiero de ingresos y egresos
- `BalanceGeneral` - Documento de activos y pasivos
- `RegistrosPatronales` - Documento de registros de empleadores

## 📁 Estructura del Repositorio

```
apolo_procesamiento_inteligente_preavaluo/
├── apolo_procesamiento_inteligente.py  # Función principal (entry point)
├── requirements.txt                     # Dependencias Python
├── workflow.yaml                        # Definición de Cloud Workflow
├── Dockerfile                           # Configuración Docker para Cloud Run
├── docker-compose.yml                   # Desarrollo local con Docker
├── .dockerignore                        # Archivos excluidos de imagen Docker
├── .env.example                         # Plantilla de variables de entorno
├── pyrightconfig.json                   # Configuración de type checking
├── runtime.txt                          # Especificación Python 3.11
├── .python-version                      # Versión Python para pyenv
├── .gitignore                           # Archivos ignorados por Git
├── README.md                            # Este archivo
├── LICENSE                              # Licencia MIT
│
├── docs/                                # 📚 Documentación completa
│   ├── README.md                        # Índice de documentación
│   ├── QUICKSTART.md                    # Guía de inicio rápido
│   ├── DEPLOY_GUIDE.md                  # Guía detallada de despliegue
│   ├── TESTING.md                       # Guía de pruebas
│   └── PROJECT_STATUS.md                # Estado actual del proyecto
│
├── scripts/                             # 🛠️ Scripts de automatización
│   ├── README.md                        # Índice de scripts
│   ├── powershell/                      # Scripts para Windows
│   │   ├── README.md                    # Documentación PowerShell
│   │   ├── build-docker.ps1             # Construir imagen Docker local
│   │   ├── deploy-cloudrun.ps1          # Desplegar a Cloud Run
│   │   ├── deploy-complete.ps1          # Setup completo desde cero
│   │   └── test-cloudrun.ps1            # Suite de pruebas
│   └── bash/                            # Scripts para Linux/Mac
│       ├── README.md                    # Documentación Bash
│       ├── build-docker.sh              # Construir imagen Docker local
│       ├── deploy-cloudrun.sh           # Desplegar a Cloud Run
│       └── test-cloudrun.sh             # Suite de pruebas
│
└── infrastructure/                      # 🏗️ Infraestructura como código
    └── terraform/                       # Configuración Terraform (opcional)
        ├── README.md                    # Guía de Terraform
        ├── main.tf                      # Recursos principales
        ├── variables.tf                 # Variables de entrada
        ├── outputs.tf                   # Valores de salida
        ├── providers.tf                 # Configuración de providers
        ├── deploy.ps1                   # Script de despliegue PowerShell
        ├── deploy.sh                    # Script de despliegue Bash
        └── env/                         # Archivos de variables por entorno
            ├── dev.tfvars
            ├── qa.tfvars
            ├── prod.tfvars
            └── example.tfvars
```

## 🎯 Características Implementadas

### ✅ Validación de PDF
- Verifica magic bytes (%PDF-) antes de procesar
- Rechaza archivos corruptos o no-PDF
- Reporta archivos inválidos en respuesta de error

### ✅ Idempotencia Robusta
- Hash determin\u00edstico: `SHA256(folioId:fileId)[:16]`
- Lease mechanism con timeout de 10 minutos
## 🛠️ Guías de Inicio

### 🚀 Inicio Rápido
Para comenzar rápidamente:
```powershell
# 1. Lee la guía de inicio
Get-Content docs\QUICKSTART.md

# 2. Despliega con un comando
.\scripts\powershell\deploy-complete.ps1
```

Ver **[docs/QUICKSTART.md](docs/QUICKSTART.md)** para guía paso a paso completa.

### 📖 Guías Completas

| Guía | Propósito | Cuándo Usarla |
|------|-----------|---------------|
| **[QUICKSTART.md](docs/QUICKSTART.md)** | Inicio rápido para principiantes | Primera vez, instalación desde cero |
| **[DEPLOY_GUIDE.md](docs/DEPLOY_GUIDE.md)** | Despliegue técnico detallado | Necesitas entender cada paso |
| **[TESTING.md](docs/TESTING.md)** | Cómo probar el servicio | Validar que funciona correctamente |
| **[PROJECT_STATUS.md](docs/PROJECT_STATUS.md)** | Estado y roadmap | Ver qué está listo y qué falta |

### 🛠️ Scripts Disponibles

Todos los scripts están documentados en **[scripts/README.md](scripts/README.md)**

**Windows (PowerShell):**
```powershell
# Construir imagen Docker local
.\scripts\powershell\build-docker.ps1

# Desplegar a Cloud Run
.\scripts\powershell\deploy-cloudrun.ps1 -Environment dev -ProjectId "tu-project-id"

# Setup completo desde cero
.\scripts\powershell\deploy-complete.ps1

# Probar servicio
.\scripts\powershell\test-cloudrun.ps1 -ServiceUrl "https://tu-servicio.run.app" -Mode batch
```

**Linux/Mac (Bash):**
```bash
# Construir imagen Docker local
./scripts/bash/build-docker.sh

# Desplegar a Cloud Run
export GCP_PROJECT_ID="tu-project-id"
./scripts/bash/deploy-cloudrun.sh dev

# Probar servicio
./scripts/bash/test-cloudrun.sh "https://tu-servicio.run.app" batch
```

Ver documentación completa en:
- **[scripts/powershell/README.md](scripts/powershell/README.md)** - Scripts Windows
- **[scripts/bash/README.md](scripts/bash/README.md)** - Scripts Linux/Mac

## 🧪 Desarrollo Local

### Opción 1: Ejecutar con Docker (Recomendado)

```powershell
# Windows
.\scripts\powershell\build-docker.ps1
docker run -p 8080:8080 --rm apolo-procesamiento-inteligente:local-latest

# Probar (en otra terminal)
.\scripts\powershell\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080"
```

```bash
# Linux/Mac
./scripts/bash/build-docker.sh
docker run -p 8080:8080 --rm apolo-procesamiento-inteligente:local-latest

# Probar (en otra terminal)
./scripts/bash/test-cloudrun.sh "http://localhost:8080" individual
```

### Opción 2: Ejecutar con Python directamente

```bash
# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt

# Configurar credenciales
export GOOGLE_APPLICATION_CREDENTIALS="path/to/credentials.json"
export BUCKET_NAME="preavaluos-pdf"

# Ejecutar con functions-framework
functions-framework --target=document_processor --debug --port=8080
```

## 🔧 Configuración y Despliegue a GCP

### Requisitos Previos
- Google Cloud SDK (gcloud CLI)
- Docker Desktop
- Proyecto GCP creado
- Permisos de Owner/Editor en el proyecto

### Despliegue Rápido

**Primera vez (setup completo):**
```powershell
# Windows
.\scripts\powershell\deploy-complete.ps1

# Linux/Mac
export GCP_PROJECT_ID="tu-project-id"
./scripts/bash/deploy-cloudrun.sh dev
```

**Redespliegue (después de cambios):**
```powershell
# Windows
.\scripts\powershell\deploy-cloudrun.ps1 -Environment prod -ProjectId "tu-project-id"

# Linux/Mac
export GCP_PROJECT_ID="tu-project-id"
./scripts/bash/deploy-cloudrun.sh prod
```

### Validación Post-Despliegue

```powershell
# Windows
.\scripts\powershell\test-cloudrun.ps1 -ServiceUrl "https://tu-servicio.run.app" -Mode batch

# Linux/Mac
./scripts/bash/test-cloudrun.sh "https://tu-servicio.run.app" batch
```

> 📖 **Guía completa**: Ver [docs/DEPLOY_GUIDE.md](docs/DEPLOY_GUIDE.md) para instrucciones detalladas paso a paso.

## 📋 Variables de Entorno

| Variable | Descripción | Default | Requerida |
|----------|-------------|---------|-----------|
| `BUCKET_NAME` | Nombre del bucket GCS | `preavaluos-pdf` | Sí |
| `GCP_PROJECT_ID` | ID del proyecto GCP | - | Sí (scripts) |
| `GCP_REGION` | Región de despliegue | `us-south1` | No |
| `GOOGLE_APPLICATION_CREDENTIALS` | Ruta a credenciales JSON | - | Sí (local) |

## 🐳 Docker y Cloud Run

### Construcción Local

**Bash/Linux:**
```bash
# Construir imagen localmente
./build-docker.sh

# O manualmente:
docker build -t apolo-procesamiento-inteligente:local-latest .
```

**PowerShell/Windows:**
```powershell
# Construir imagen localmente
.\build-docker.ps1

# O manualmente:
docker build -t apolo-procesamiento-inteligente:local-latest .
```

### Ejecución Local con Docker

```bash
# Ejecutar contenedor localmente
docker run -p 8080:8080 --rm \
  -e BUCKET_NAME=preavaluos-pdf \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json \
  -v /path/to/credentials.json:/app/credentials.json:ro \
  apolo-procesamiento-inteligente:local-latest
```

**Probar localmente:**
```bash
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "folioId": "PRE-2025-001",
    "fileId": "balance_general.pdf",
    "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
    "workflow_execution_id": "test-123"
  }'
```

### Despliegue a Cloud Run

**Prerrequisitos:**
1. Instalar [gcloud CLI](https://cloud.google.com/sdk/docs/install)
2. Instalar [Docker Desktop](https://www.docker.com/products/docker-desktop)
3. Autenticarse: `gcloud auth login`
4. Configurar proyecto: `gcloud config set project YOUR_PROJECT_ID`
5. Crear Service Account con permisos:
   - Storage Object Viewer (para leer PDFs)
   - Firestore User (para persistencia)

**Despliegue Automático - Bash/Linux:**
```bash
# Configurar variables de entorno
export GCP_PROJECT_ID="apolo-solutions-project"
export GCP_REGION="us-south1"
export BUCKET_NAME="preavaluos-pdf"

# Desplegar a Cloud Run (dev, qa, o prod)
chmod +x deploy-cloudrun.sh
./deploy-cloudrun.sh dev
```

**Despliegue Automático - PowerShell/Windows:**
```powershell
# Configurar variables de entorno
$env:GCP_PROJECT_ID = "apolo-solutions-project"

# Desplegar a Cloud Run (dev, qa, o prod)
.\deploy-cloudrun.ps1 -Environment dev -ProjectId "apolo-solutions-project" -Region "us-south1" -BucketName "preavaluos-pdf"
```

**Despliegue Manual:**
```bash
# 1. Configurar Docker para GCR
gcloud auth configure-docker gcr.io

# 2. Construir y subir imagen
export PROJECT_ID="apolo-solutions-project"
export IMAGE_NAME="gcr.io/${PROJECT_ID}/apolo-procesamiento-inteligente"

docker build --platform linux/amd64 -t ${IMAGE_NAME}:latest .
docker push ${IMAGE_NAME}:latest

# 3. Desplegar a Cloud Run
gcloud run deploy apolo-procesamiento-inteligente \
  --image ${IMAGE_NAME}:latest \
  --platform managed \
  --region us-south1 \
  --allow-unauthenticated \
  --set-env-vars BUCKET_NAME=preavaluos-pdf \
  --memory 512Mi \
  --cpu 1 \
  --timeout 300 \
  --concurrency 80 \
  --max-instances 10 \
  --min-instances 0 \
  --service-account apolo-procesamiento-sa@${PROJECT_ID}.iam.gserviceaccount.com
```

### Características de Cloud Run

| Característica | Configuración |
|---------------|---------------|
| **Memoria** | 512 MiB |
| **CPU** | 1 vCPU |
| **Timeout** | 300s (5 minutos) |
| **Concurrencia** | 80 requests por instancia |
| **Escalado** | 0-10 instancias (auto) |
| **Puerto** | 8080 |
| **Plataforma** | linux/amd64 |

## 🌐 Despliegue en GCP (Cloud Functions)

**Nota**: Los archivos `terraform/` están disponibles para configuración por ambiente (dev, qa, prod).

```bash
# Desplegar usando Terraform
cd infrastructure/terraform
terraform init
terraform apply -var-file="env/dev.tfvars"
```

**Variables necesarias en `dev.tfvars`**:
- `project_id` - ID del proyecto GCP
- `service_name` - Nombre de la Cloud Function
- `bucket_name` - Nombre del bucket GCS a procesar
- `region` - Región de despliegue (us-south1)

## 🔄 Orquestación con Cloud Workflows

La función es invocada por `workflow.yaml`, que orquesta el flujo completo:

```yaml
callProcessor:
  call: http.post
  args:
    url: ${processor_url}
    auth:
      type: OIDC
      audience: ${processor_audience}
    body:
      folioId: ${folio_id}
      fileId: ${file_id}
      gcs_pdf_uri: ${gcs_pdf_uri}
      workflow_execution_id: ${sys.get_env("GOOGLE_CLOUD_WORKFLOW_EXECUTION_ID")}
```

**Características del Workflow**:
- Autenticación OIDC (sin credenciales estáticas)
- Reintentos automáticos con backoff exponencial
- Pasa parámetros desde el contexto del flujo
- Tracking con workflow_execution_id para correlación

## 📝 Estructura de Archivos

```
apolo_procesamiento_inteligente_preavaluo/
├── apolo_procesamiento_inteligente.py  # Cloud Function principal
├── requirements.txt                     # Dependencias Python
├── runtime.txt                          # Versión de Python (3.11)
├── .python-version                      # Versión local Python
├── workflow.yaml                        # Orquestación Cloud Workflows
├── LICENSE                              # MIT License
├── README.md                            # Documentación
│
├── Docker y Deployment
├── Dockerfile                           # Imagen Docker para Cloud Run
├── .dockerignore                        # Archivos excluidos de imagen
├── build-docker.sh                      # Script build local (Bash)
├── build-docker.ps1                     # Script build local (PowerShell)
├── deploy-cloudrun.sh                   # Despliegue completo (Bash)
├── deploy-cloudrun.ps1                  # Despliegue completo (PowerShell)
│
├── Configuración
├── pyrightconfig.json                   # Configuración Pylance/Pyright
│
└── Infrastructure as Code
    └── infrastructure/
        └── terraform/
            ├── main.tf                  # Recursos GCP
            ├── variables.tf             # Variables Terraform
            ├── outputs.tf               # Outputs Terraform
            ├── providers.tf             # Providers GCP
            ├── deploy.sh                # Script despliegue Terraform
            ├── deploy.ps1               # Script despliegue Terraform (PS)
            └── env/
                ├── dev.tfvars           # Variables desarrollo
                ├── qa.tfvars            # Variables QA
                ├── prod.tfvars          # Variables producción
                └── example.tfvars       # Ejemplo de configuración
```

### Componentes Principales

**Core Application:**
- `apolo_procesamiento_inteligente.py` - Entry point HTTP, procesamiento de PDFs
  - `document_processor()` - Handler principal
  - `simulate_classification()` - Clasificación de documentos
  - `simulate_extraction()` - Extracción de campos
  - `_is_valid_pdf()` - Validación de PDFs por magic bytes
  - `_check_and_acquire_lease()` - Idempotencia con Firestore
  - `_persist_result()` - Persistencia de resultados

**Docker & Deployment:**
- Scripts de construcción local (`build-docker.*`)
- Scripts de despliegue completo a Cloud Run (`deploy-cloudrun.*`)
- Configuración de imagen optimizada para producción

## 🔐 Seguridad

- **Autenticación OIDC**: Cloud Workflows autentica a Cloud Function sin exponer credenciales
- **IAM**: Service accounts granulares para acceso a GCS y otros recursos
- **No hay credenciales estáticas**: Todas las credenciales se manejan a través de GCP IAM

## ⚠️ Comportamiento Actual (Simulado)

**Nota**: Las funciones de clasificación y extracción actualmente son simuladas para demostración.

- `simulate_classification()` - Retorna un tipo de documento aleatorio con confianza entre 80-99%
- `simulate_extraction()` - Retorna campos genéricos según el tipo de documento
- No realiza procesamiento real de PDF o acceso a Document AI (pendiente implementación)

## 🤝 Contribución

1. Fork el repositorio
2. Crea una rama: `git checkout -b feature/nueva-feature`
3. Commit: `git commit -am 'Añade nueva feature'`
4. Push: `git push origin feature/nueva-feature`
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo licencia MIT. Ver `LICENSE` para detalles.

---

**Apolo Solutions** © 2025. Todos los derechos reservados.
