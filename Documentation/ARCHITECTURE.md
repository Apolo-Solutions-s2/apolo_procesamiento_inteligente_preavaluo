# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT APPLICATIONS                            │
│                    (Web App / API Gateway / Backend)                     │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                │ HTTP POST (JSON)
                                │ or
                                │ Cloud Workflows Trigger
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      ORCHESTRATION LAYER (Optional)                      │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    Cloud Workflows                                │   │
│  │  • OIDC Authentication                                            │   │
│  │  • Automatic Retries with Exponential Backoff                    │   │
│  │  • Execution Tracking & Correlation                              │   │
│  └────────────────────────────┬─────────────────────────────────────┘   │
└─────────────────────────────────┼─────────────────────────────────────────┘
                                  │
                                  │ OIDC Authenticated HTTP POST
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      PROCESSING MICROSERVICE                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │               Cloud Run Service (Containerized)                   │   │
│  │                                                                   │   │
│  │  apolo-procesamiento-inteligente                                 │   │
│  │  • Python 3.11 + Flask + functions-framework                     │   │
│  │  • Serverless, Auto-scaling (0-1000 instances)                   │   │
│  │  • Memory: 512MB - 2GB                                           │   │
│  │  • Region: us-south1 (Dallas)                                    │   │
│  │  • Timeout: 300s (5 min)                                         │   │
│  └────────────┬──────────────┬──────────────┬────────────────────────┘   │
└───────────────┼──────────────┼──────────────┼──────────────────────────────┘
                │              │              │
                │              │              │
    ┌───────────▼─────┐  ┌────▼─────┐  ┌────▼──────────────┐
    │                 │  │          │  │                    │
┌───▼──────────────┐  │  │          │  │  ┌──────────────┐ │
│  Google Cloud    │  │  │          │  │  │  Firestore   │ │
│  Storage (GCS)   │  │  │Document  │  │  │  Database    │ │
│                  │  │  │   AI     │  │  │              │ │
│  Bucket:         │  │  │          │  │  │  Database:   │ │
│  preavaluos-pdf  │  │  │(Future)  │  │  │  apolo-      │ │
│                  │  │  │          │  │  │  preavaluos  │ │
│  • PDFs Storage  │  │  │• Classi- │  │  │  -dev        │ │
│  • Versioning    │  │  │  fier    │  │  │              │ │
│  • Lifecycle     │  │  │• Extrac- │  │  │  Collections:│ │
│                  │  │  │  tor     │  │  │  • runs/     │ │
│  Region:         │  │  │          │  │  │    └─docs/   │ │
│  us-south1       │  │  │          │  │  │              │ │
└──────────────────┘  │  │          │  │  │  Features:   │ │
                      │  │          │  │  │  • Idempo-   │ │
                      │  │          │  │  │    tency     │ │
                      │  │          │  │  │  • Audit     │ │
                      │  │          │  │  │    Trail     │ │
                      │  └──────────┘  │  │  • Lease     │ │
                      │                │  │    Locking   │ │
                      │                │  └──────────────┘ │
                      │                │                    │
                      │   INTEGRATION  │   PERSISTENCE     │
                      │   LAYER        │   LAYER           │
                      └────────────────┴───────────────────┘
```

## Data Flow - Processing Pipeline

### Activation Trigger: IS_READY Sentinel File

El servicio se activa automáticamente cuando se detecta un archivo `IS_READY` en GCS. Este es el flujo completo:

```
1. Usuario sube PDFs a carpeta del bucket
   gs://apolo-preavaluos-pdf-dev/CARPETA-UUID/
   ├── documento1.pdf
   ├── documento2.pdf
   └── documento3.pdf

2. Usuario sube archivo IS_READY (sin extensión, vacío)
   gs://apolo-preavaluos-pdf-dev/CARPETA-UUID/IS_READY

3. Eventarc detecta evento 'object.finalize' en bucket
   └─ Validación: ¿El nombre termina en 'is_ready' (case-insensitive)?
   
4. Trigger activa Cloud Run: apolo-procesamiento-inteligente
   ├─ Extrae nombre de carpeta: CARPETA-UUID
   ├─ Genera folio_id: hash(bucket:carpeta) para unicidad
   └─ Inicia procesamiento de la carpeta
   
5. Listado de archivos PDF
   ├─ Obtiene TODOS los PDFs en la carpeta
   ├─ EXCLUYE el archivo IS_READY (no es PDF, está vacío)
   └─ Encuentra N documentos para procesar
   
6. Procesamiento paralelo (ThreadPoolExecutor)
   └─ Para cada PDF:
      ├─ Validación PDF (verificar magic bytes %PDF-)
      ├─ Clasificación con Document AI (ER/ESF/EFE)
      ├─ Extracción de datos estructurados
      ├─ Persistencia en Firestore (folio/docId/extraction)
      └─ Manejo de errores y DLQ
   
7. Finalización
   ├─ Actualiza estado del folio (DONE/DONE_WITH_ERRORS)
   ├─ Registra estadísticas (total/exitosos/errores)
   └─ Almacena en Firestore colección 'folios'
```

**Características importantes:**
- ✅ **Case-insensitive**: Detecta "IS_READY", "is_ready", "Is_Ready", etc.
- ✅ **Procesamiento paralelo**: Procesa múltiples PDFs simultáneamente
- ✅ **Idempotencia**: Evita reprocesar documentos usando generation numbers
- ✅ **Manejo de errores**: Publica errores al DLQ (Pub/Sub)
- ✅ **Firestore integrado**: Persistencia automática de resultados

### Mode 1: Individual Document Processing
```
1. Client Request (HTTP POST)
   ├─ folioId: "PRE-2025-001"
   ├─ fileId: "balance.pdf"
   └─ gcs_pdf_uri: "gs://bucket/path/file.pdf"
   
2. Service Entry → document_processor()
   
3. Idempotency Check (Firestore)
   ├─ Generate deterministic docId = hash(folioId:fileId)
   ├─ Query: runs/{runId}/documents/{docId}
   └─ If exists & completed → return cached result
   
4. PDF Validation
   ├─ Read magic bytes from GCS
   └─ Verify %PDF- header
   
5. Document AI Classification (Simulated)
   ├─ ESTADO_RESULTADOS
   ├─ ESTADO_SITUACION_FINANCIERA
   └─ ESTADO_FLUJOS_EFECTIVO
   
6. Document AI Extraction (Simulated)
   ├─ Extract structured fields by document type
   └─ Generate metadata
   
7. Firestore Persistence
   ├─ Save classification + extraction results
   └─ Update run-level counters
   
8. Response (JSON)
   └─ Complete results with metadata
```

### Mode 2: Batch Processing (Folder)
```
1. Client Request (HTTP POST)
   ├─ folder_prefix: "PRE-2025-001/"
   └─ preavaluo_id: "PRE-2025-001"
   
2. GCS Discovery
   ├─ List all .pdf files in folder
   ├─ Filter by extensions
   └─ Limit: max_items (default 500)
   
3. Batch Validation
   └─ Validate each PDF magic bytes
   
4. For each valid PDF:
   ├─ Check idempotency
   ├─ Classify document type
   ├─ Extract structured data
   └─ Persist to Firestore
   
5. Aggregate Response
   ├─ processedCount
   ├─ failedCount
   └─ results[] array with all documents
```

### Mode 3: Document AI Batch Format
```
1. Client Request (HTTP POST)
   └─ fileList: [
       {gcsUri: "gs://...", file_name: "doc1.pdf"},
       {gcsUri: "gs://...", file_name: "doc2.pdf"}
     ]
   
2. Process each document independently
   └─ Same pipeline as Mode 1
   
3. Return aggregated results
```

## Component Responsibilities

### Cloud Run Service
**Purpose**: Serverless compute engine for document processing  
**Responsibilities**:
- Request validation and routing
- Orchestrate processing pipeline
- Error handling and logging
- Response formatting

### Google Cloud Storage (GCS)
**Purpose**: Durable object storage for PDF documents  
**Responsibilities**:
- Store source PDF files
- Provide versioning
- Enable parallel access
- Lifecycle management

### Firestore
**Purpose**: NoSQL database for results and idempotency  
**Responsibilities**:
- Store processing results
- Enable idempotency through caching
- Track run-level metadata
- Provide audit trail

### Document AI (Future)
**Purpose**: Machine learning-based document intelligence  
**Responsibilities**:
- Classify document types
- Extract structured data
- OCR when needed
- Confidence scoring

### Cloud Workflows (Optional)
**Purpose**: Orchestration and retry logic  
**Responsibilities**:
- Handle complex multi-step flows
- Automatic retries with backoff
- OIDC authentication
- Execution tracking

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Network Security                                         │
│     ├─ HTTPS Only (TLS 1.2+)                                │
│     ├─ Cloud Run ingress: all (or internal)                 │
│     └─ VPC connector (optional)                             │
│                                                              │
│  2. Authentication & Authorization                           │
│     ├─ OIDC tokens (Cloud Workflows)                        │
│     ├─ Service Account based                                │
│     └─ IAM role bindings                                    │
│                                                              │
│  3. Service Account Permissions                              │
│     ├─ Cloud Run SA:                                        │
│     │   ├─ storage.objects.get (GCS read)                   │
│     │   └─ datastore.user (Firestore read/write)           │
│     └─ Workflows SA (if used):                              │
│         └─ run.invoker (Cloud Run invocation)              │
│                                                              │
│  4. Data Security                                            │
│     ├─ Encryption at rest (default GCP)                    │
│     ├─ Encryption in transit (TLS)                         │
│     └─ No sensitive data in logs                           │
│                                                              │
│  5. Container Security                                       │
│     ├─ Non-root user (UID 1000)                            │
│     ├─ Minimal base image (python:3.11-slim)               │
│     └─ No unnecessary packages                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Scalability & Performance

### Auto-scaling Configuration
- **Min instances**: 0 (cost optimization)
- **Max instances**: 1000 (or custom limit)
- **Concurrency**: 80 requests per instance
- **CPU allocation**: during request processing only
- **Memory**: 512MB - 2GB (configurable)

### Performance Characteristics
- **Cold start**: ~2-3 seconds (first request)
- **Warm request**: ~100-500ms (cached instances)
- **Document processing**: ~1-2s per document (simulated)
- **Batch processing**: Parallel processing capability

### Cost Optimization Strategies
1. **Idempotency**: Prevents reprocessing of same documents
2. **Early validation**: Fail-fast on invalid PDFs before AI calls
3. **Scale to zero**: No cost when not processing
4. **Efficient batching**: Process multiple documents in single run
5. **Result caching**: Firestore cache reduces redundant operations

## Monitoring & Observability

### Structured Logging
```json
{
  "event_type": "progress",
  "ts_utc": "2025-12-04T10:30:00Z",
  "run_id": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "step": "CLASSIFY_START",
  "percent": 40
}
```

### Key Metrics
- Request latency (p50, p95, p99)
- Error rates by stage
- Document processing throughput
- Firestore cache hit rate
- GCS operation latency

### Alerting (Production)
- Error rate > 5%
- Latency p99 > 10s
- Failed document rate > 10%
- Budget threshold alerts

## Deployment Regions

**Primary**: us-south1 (Dallas, Texas)  
**Rationale**:
- Low latency for US operations
- Proximity to core business
- Cost-effective
- High availability zone

**Future Multi-region** (if needed):
- us-central1 (Iowa) - backup
- us-east1 (South Carolina) - east coast coverage

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Runtime | Python | 3.11 | Application code |
| Framework | Flask | Latest | HTTP handling |
| Function Framework | functions-framework | 3.x | Cloud Function compatibility |
| Cloud Platform | Google Cloud Platform | - | Infrastructure |
| Compute | Cloud Run (Gen 2) | Latest | Serverless container |
| Storage | Cloud Storage | - | PDF storage |
| Database | Firestore | Native mode | Result persistence |
| Container | Docker | 20+ | Containerization |
| Orchestration | Cloud Workflows | - | Optional orchestration |
| IaC | Terraform | 1.5+ | Infrastructure as Code |
| CI/CD | Cloud Build | - | Build & Deploy |

## Disaster Recovery

### Backup Strategy
- **GCS**: Object versioning enabled (90-day retention)
- **Firestore**: Daily automated backups
- **Code**: Version controlled in GitHub
- **Infrastructure**: Defined in Terraform

### Recovery Procedures
1. **Service failure**: Auto-restart by Cloud Run
2. **Region outage**: Manual failover to backup region
3. **Data corruption**: Restore from Firestore backup
4. **Code rollback**: Deploy previous container image

### RTO/RPO
- **RTO** (Recovery Time Objective): < 15 minutes
- **RPO** (Recovery Point Objective): < 1 hour
