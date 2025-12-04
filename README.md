# Apolo - Procesamiento Inteligente de Documentos Financieros

Solución de procesamiento inteligente de documentos financieros para **Apolo Solutions**.

## 📋 Descripción

**Propósito**
Cloud Function que procesa documentos financieros desde Google Cloud Storage (GCS) para el módulo de preavalúos de Apolo. La función realiza tres etapas principales:
- ✅ **Validación PDF**: Verifica que los archivos sean PDFs válidos mediante magic bytes
- ✅ **Clasificación**: Identifica el tipo de documento (Estados de Resultados, Balance General, Registros Patronales)
- ✅ **Extracción**: Extrae campos estructurados según el tipo de documento
- ✅ **Persistencia**: Guarda resultados en Firestore con idempotencia

**Contexto**
Se ejecuta como Cloud Function (HTTP) serverless en GCP bajo el enfoque de orquestación con Cloud Workflows. La función valida, clasifica y extrae datos de documentos PDF, persistiendo resultados en Firestore para trazabilidad y evitar reprocesamiento.

## 🚀 Características Técnicas

| Aspecto | Especificación |
|--------|----------------|
| **Tipo de Recurso** | Cloud Run (Containerizado) |
| **Lenguaje** | Python 3.11+ |
| **Framework** | Flask + functions-framework |
| **Patrón de Invocación** | HTTP directo o vía Cloud Workflows (OIDC) |
| **Región** | us-south1 (Dallas) - configurable |
| **Almacenamiento** | Google Cloud Storage (GCS) |
| **Base de Datos** | Cloud Firestore (persistencia e idempotencia) |
| **Seguridad** | Service Account + OIDC (opcional con Workflows) |

### 🔄 Modos de Operación

**Modo 1: Invocación Directa (Actual)**
```
Cliente/Backend → HTTP POST → Cloud Run → GCS + Firestore
```
✅ Ideal para pruebas y desarrollo  
✅ Integración directa en tu aplicación  
✅ Control total de la lógica de llamada  

**Modo 2: Con Cloud Workflows (Producción)**
```
Cliente/Backend → Cloud Workflows → HTTP POST (OIDC) → Cloud Run → GCS + Firestore
```
✅ Orquestación de flujos complejos  
✅ Reintentos automáticos con backoff  
✅ Autenticación OIDC sin credenciales estáticas  
✅ Trazabilidad completa del flujo  

> **Nota**: El microservicio funciona en **ambos modos**. Cloud Workflows es opcional y se agregará en producción para orquestación avanzada.

## 📦 Dependencias Principales

- **functions-framework** (v3.x) - Para ejecutar como Cloud Function
- **Flask** - Servidor HTTP
- **google-cloud-storage** (v2.10.0+) - Para listar y acceder a objetos en GCS
- **google-cloud-firestore** (v2.11.0+) - Para persistencia e idempotencia

## 🔍 Comportamiento Esperado

**Entrada (Request JSON) - Modo Individual**
```json
{
  "folioId": "PRE-2025-001",
  "fileId": "balance_general.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
  "workflow_execution_id": "wf-abc123"
}
```

**Entrada (Request JSON) - Modo Batch**
```json
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001",
  "extensions": [".pdf"],
  "max_items": 500,
  "workflow_execution_id": "wf-abc123"
}
```

**Flujo de Ejecución**
1. **Validación**: Verifica parámetros y formato de entrada
2. **Listado** (modo batch): Lista archivos del folder especificado en GCS
3. **Validación PDF**: Lee magic bytes (%PDF-) para confirmar formato válido
4. **Idempotencia**: Verifica en Firestore si el documento ya fue procesado
5. **Clasificación**: Identifica tipo de documento con simulador (preparado para Document AI)
6. **Extracción**: Extrae campos estructurados según el tipo
7. **Persistencia**: Guarda resultados en Firestore con metadata completa
8. **Respuesta**: Retorna JSON con resultados de todos los documentos
   - Registra progreso y timestamps UTC
4. Retorna resultado consolidado con todos los documentos procesados

**Salida (Response JSON) - Éxito**
```json
{
  "status": "processed",
  "run_id": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "bucket": "preavaluos-pdf",
  "folder_prefix": "PRE-2025-001/",
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
