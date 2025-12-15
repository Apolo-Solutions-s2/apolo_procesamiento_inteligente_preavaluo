# Guía de Migración a la Versión Alineada con Especificación

## Cambios Principales

### 1. Activación del Microservicio

**Antes (HTTP Manual):**
```bash
curl -X POST https://service-url.run.app \
  -H "Content-Type: application/json" \
  -d '{"folder_prefix": "PRE-2025-001/"}'
```

**Ahora (Eventarc Automático):**
```bash
# El microservicio se activa automáticamente al crear is_ready
gsutil cp /dev/null gs://preavaluos-pdf/PRE-2025-001/is_ready
```

### 2. Configuración de Eventarc

Crear trigger de Eventarc:

```bash
gcloud eventarc triggers create apolo-procesamiento-trigger \
  --location=us-south1 \
  --destination-run-service=apolo-procesamiento-inteligente \
  --destination-run-region=us-south1 \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=preavaluos-pdf" \
  --service-account=apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com
```

### 3. Variables de Entorno Requeridas

Actualizar deployment con las nuevas variables:

```yaml
env:
  - name: GCP_PROJECT_ID
    value: "your-project-id"
  - name: PROCESSOR_LOCATION
    value: "us"
  - name: CLASSIFIER_PROCESSOR_ID
    value: "your-classifier-processor-id"
  - name: EXTRACTOR_PROCESSOR_ID
    value: "your-extractor-processor-id"
  - name: DLQ_TOPIC_NAME
    value: "apolo-preavaluo-dlq"
  - name: MAX_CONCURRENT_DOCS
    value: "8"
  - name: MAX_RETRIES
    value: "3"
```

### 4. Esquema Firestore Actualizado

**Antes:**
```
runs/{runId}/documents/{docId}
```

**Ahora:**
```
folios/{folioId}/
├── documentos/{docId}/
│   └── extracciones/{extractionId}/
```

#### Script de Migración de Datos

```python
from google.cloud import firestore

db = firestore.Client()

# Migrar de runs a folios
runs = db.collection("runs").stream()
for run in runs:
    run_data = run.to_dict()
    folio_id = run.id  # O extraer de los datos
    
    # Crear folio
    folio_ref = db.collection("folios").document(folio_id)
    folio_ref.set({
        "bucket": run_data.get("bucket", ""),
        "folder_prefix": run_data.get("folderPrefix", ""),
        "status": run_data.get("status", "DONE"),
        "total_docs": 0,
        "processed_docs": 0,
        "created_at": run_data.get("createdAt"),
    })
    
    # Migrar documentos
    docs = db.collection("runs").document(run.id).collection("documents").stream()
    for doc in docs:
        doc_data = doc.to_dict()
        doc_ref = folio_ref.collection("documentos").document(doc.id)
        doc_ref.set({
            "gcs_uri": doc_data.get("gcsUri", ""),
            "generation": doc_data.get("generation", ""),
            "file_id": doc_data.get("fileId", ""),
            "status": doc_data.get("status", "DONE"),
            "doc_type": doc_data.get("classification", {}).get("document_type", ""),
        })
```

### 5. Document AI Processors

#### Crear Classifier Processor

```bash
# En la consola de GCP:
# 1. Ir a Document AI > Processor Gallery
# 2. Crear Custom Document Classifier
# 3. Entrenar con tipos: ESTADO_RESULTADOS, ESTADO_SITUACION_FINANCIERA, ESTADO_FLUJOS_EFECTIVO
# 4. Copiar PROCESSOR_ID

export CLASSIFIER_PROCESSOR_ID="abc123..."
```

#### Crear Extractor Processor

```bash
# En la consola de GCP:
# 1. Crear Custom Document Extractor
# 2. Definir schema con campos:
#    - LINE_ITEM_NAME, LINE_ITEM_VALUE, COLUMN_YEAR
#    - SECTION_HEADER, TOTAL_LABEL
#    - CURRENCY, UNITS_SCALE, REPORTING_PERIOD
#    - ORG_NAME, STATEMENT_TITLE
# 3. Entrenar con documentos de muestra
# 4. Copiar PROCESSOR_ID

export EXTRACTOR_PROCESSOR_ID="def456..."
```

### 6. Crear Tópico DLQ en Pub/Sub

```bash
gcloud pubsub topics create apolo-preavaluo-dlq \
  --project=your-project-id

# Crear suscripción para monitoreo
gcloud pubsub subscriptions create apolo-dlq-monitor \
  --topic=apolo-preavaluo-dlq \
  --ack-deadline=60
```

### 7. Actualizar Service Account Permissions

```bash
# Storage
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Firestore
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/datastore.user"

# Document AI
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/documentai.apiUser"

# Pub/Sub
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

# Eventarc
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"

gcloud run services add-iam-policy-binding apolo-procesamiento-inteligente \
  --region=us-south1 \
  --member="serviceAccount:apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

### 8. Despliegue Actualizado

```bash
# Construir imagen
docker build -t gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v2 .

# Push
docker push gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v2

# Deploy con nuevas configuraciones
gcloud run deploy apolo-procesamiento-inteligente \
  --image=gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v2 \
  --region=us-south1 \
  --platform=managed \
  --no-allow-unauthenticated \
  --service-account=apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com \
  --set-env-vars="GCP_PROJECT_ID=PROJECT_ID,PROCESSOR_LOCATION=us,CLASSIFIER_PROCESSOR_ID=abc123,EXTRACTOR_PROCESSOR_ID=def456,DLQ_TOPIC_NAME=apolo-preavaluo-dlq,MAX_CONCURRENT_DOCS=8" \
  --memory=2Gi \
  --timeout=900 \
  --concurrency=1 \
  --max-instances=10
```

### 9. Flujo de Prueba

```bash
# 1. Subir PDFs a una carpeta
gsutil cp documento1.pdf gs://preavaluos-pdf/TEST-001/
gsutil cp documento2.pdf gs://preavaluos-pdf/TEST-001/
gsutil cp documento3.pdf gs://preavaluos-pdf/TEST-001/

# 2. Crear archivo is_ready (trigger del procesamiento)
gsutil cp /dev/null gs://preavaluos-pdf/TEST-001/is_ready

# 3. Monitorear logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=apolo-procesamiento-inteligente" \
  --limit=50 \
  --format=json

# 4. Verificar resultados en Firestore
# Ir a Firestore console > folios > TEST-001 > documentos

# 5. Monitorear DLQ (si hay errores)
gcloud pubsub subscriptions pull apolo-dlq-monitor --auto-ack --limit=10
```

### 10. Diferencias Clave en el Código

| Aspecto | Versión Anterior | Nueva Versión |
|---------|------------------|---------------|
| Entry Point | `@functions_framework.http` | `@functions_framework.cloud_event` |
| Trigger | HTTP POST manual | Eventarc automático (is_ready) |
| Document AI | Simulación | Integración real con retry |
| Procesamiento | Secuencial (for loop) | Paralelo (ThreadPoolExecutor) |
| Idempotencia | Solo hash | hash + generation |
| Firestore | `runs/documents` | `folios/documentos/extracciones` |
| DLQ | No implementado | Pub/Sub con retry |
| Logs | Básicos | Estructurados por etapa |

### 11. Monitoreo y Observabilidad

#### Queries de Logs Útiles

```
# Procesos iniciados
resource.type="cloud_run_revision"
resource.labels.service_name="apolo-procesamiento-inteligente"
jsonPayload.event_type="folder_processing_start"

# Procesos completados
jsonPayload.event_type="folder_processing_complete"

# Errores
severity="ERROR"

# Por folio específico
jsonPayload.folio_id="TEST-001"
```

#### Métricas en Cloud Monitoring

- Carpetas procesadas por día
- Documentos procesados por carpeta
- Tasa de error por tipo de documento
- Latencia promedio por documento
- Uso de concurrencia

### 12. Rollback Plan

Si necesitas revertir:

```bash
# Deploy versión anterior
gcloud run deploy apolo-procesamiento-inteligente \
  --image=gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v1 \
  --region=us-south1

# Eliminar trigger de Eventarc
gcloud eventarc triggers delete apolo-procesamiento-trigger \
  --location=us-south1

# Restaurar flujo HTTP manual
# (usar Cloud Workflows o llamadas HTTP directas)
```

### 13. Checklist Pre-Producción

- [ ] Document AI processors creados y entrenados
- [ ] Variables de entorno configuradas
- [ ] Service account con permisos correctos
- [ ] Eventarc trigger creado
- [ ] DLQ topic y subscription creadas
- [ ] Firestore índices creados (si necesario)
- [ ] Pruebas con carpetas de test
- [ ] Monitoreo configurado
- [ ] Alertas definidas
- [ ] Documentación actualizada
- [ ] Plan de rollback probado

## Soporte

Para preguntas o problemas, contactar al equipo de DevOps o revisar:
- [Documentación completa](Documentation/README.md)
- [Architecture](Documentation/ARCHITECTURE.md)
- [Logs en Cloud Logging](https://console.cloud.google.com/logs)
