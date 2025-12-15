# ⚠️ IMPORTANTE: Cambios en la Versión 2.0

## 🎯 Alineación con Especificación Oficial

Esta versión del microservicio ha sido completamente refactorizada para alinearse con la **especificación oficial del documento "Contexto y Definición del Microservicio"**.

### 📋 Cambios Implementados

#### ✅ 1. Activación por Eventarc
- **Antes**: HTTP POST manual
- **Ahora**: Activación automática mediante Eventarc al detectar archivo `is_ready`
- **Beneficio**: Procesamiento automático sin intervención manual

#### ✅ 2. Document AI Real
- **Antes**: Simulación de clasificación y extracción
- **Ahora**: Integración completa con Document AI Classifier y Extractor
- **Beneficio**: Procesamiento inteligente real de documentos financieros

#### ✅ 3. Procesamiento Paralelo
- **Antes**: Secuencial (un documento a la vez)
- **Ahora**: Paralelo con ThreadPoolExecutor (hasta 8 documentos simultáneos)
- **Beneficio**: ~8x más rápido para lotes de 60 documentos

#### ✅ 4. Generation de GCS
- **Antes**: Idempotencia solo por nombre de archivo
- **Ahora**: Idempotencia por `gcs_uri + generation`
- **Beneficio**: Detecta cambios en archivos con mismo nombre

#### ✅ 5. Esquema Firestore Jerárquico
- **Antes**: `runs/{runId}/documents/{docId}`
- **Ahora**: `folios/{folioId}/documentos/{docId}/extracciones/{extractionId}`
- **Beneficio**: Mayor organización y trazabilidad completa

#### ✅ 6. Dead Letter Queue (DLQ)
- **Antes**: No implementado
- **Ahora**: Pub/Sub DLQ para documentos fallidos
- **Beneficio**: Manejo robusto de errores y reproceso manual

#### ✅ 7. Reintentos con Backoff Exponencial
- **Antes**: Sin reintentos automáticos
- **Ahora**: Hasta 3 intentos con delay exponencial
- **Beneficio**: Manejo resiliente de errores transitorios

---

## 🚀 Inicio Rápido

### Archivo Principal

El código actualizado está en:
```
apolo_procesamiento_inteligente_v2.py
```

Este archivo reemplaza funcionalmente a `apolo_procesamiento_inteligente.py`

### Configuración Requerida

#### Variables de Entorno

```bash
# Requeridas
export GCP_PROJECT_ID="your-project-id"
export CLASSIFIER_PROCESSOR_ID="your-classifier-id"
export EXTRACTOR_PROCESSOR_ID="your-extractor-id"

# Opcionales (con defaults)
export PROCESSOR_LOCATION="us"
export DLQ_TOPIC_NAME="apolo-preavaluo-dlq"
export MAX_CONCURRENT_DOCS="8"
export MAX_RETRIES="3"
export RETRY_INITIAL_DELAY="1.0"
export RETRY_MULTIPLIER="2.0"
export RETRY_MAX_DELAY="60.0"
```

#### Dependencias

El `requirements.txt` ha sido actualizado con:
```
google-cloud-documentai>=2.20.0
google-cloud-pubsub>=2.18.0
```

---

## 📐 Arquitectura Actualizada

```
┌─────────────────────────────────────────────────────────────────┐
│                         GCS Bucket                               │
│                    preavaluos-pdf/                               │
│  PRE-2025-001/                                                   │
│  ├── documento1.pdf                                              │
│  ├── documento2.pdf                                              │
│  ├── documento3.pdf                                              │
│  └── is_ready  ← TRIGGER (0 bytes, sin extensión)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ object.finalize event
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Eventarc                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Trigger: apolo-procesamiento-trigger                  │     │
│  │  - Event: google.cloud.storage.object.v1.finalized    │     │
│  │  - Filter: bucket=preavaluos-pdf                      │     │
│  └────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ CloudEvent
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cloud Run Service                             │
│                                                                  │
│  process_folder_on_ready(cloud_event)                           │
│  ├── 1. Validar is_ready sentinel                              │
│  ├── 2. Listar PDFs en carpeta                                 │
│  ├── 3. Procesar en paralelo (MAX_CONCURRENT_DOCS=8)          │
│  │   └── ThreadPoolExecutor                                    │
│  │       ├── Thread 1: doc1.pdf                                │
│  │       ├── Thread 2: doc2.pdf                                │
│  │       ├── ...                                               │
│  │       └── Thread 8: doc8.pdf                                │
│  └── 4. Actualizar estado final                                │
└─────────────────────────────────────────────────────────────────┘
       │                    │                    │
       │ Classify           │ Extract            │ Error
       ▼                    ▼                    ▼
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│ Document AI │      │ Document AI │      │   Pub/Sub   │
│ Classifier  │      │  Extractor  │      │     DLQ     │
└─────────────┘      └─────────────┘      └─────────────┘
       │                    │
       └──────────┬─────────┘
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Firestore                                 │
│                                                                  │
│  folios/{folioId}/                                              │
│  ├── status: PROCESSING → DONE / DONE_WITH_ERRORS              │
│  ├── total_docs: 60                                             │
│  ├── processed_docs: 60                                         │
│  └── documentos/{docId}/                                        │
│      ├── gcs_uri                                                │
│      ├── generation                                             │
│      ├── doc_type                                               │
│      ├── status: DONE / ERROR                                   │
│      └── extracciones/{extractionId}/                          │
│          ├── fields: {...}                                      │
│          └── metadata: {page_refs, bounding_boxes, ...}        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Flujo de Procesamiento

### 1. Preparación de Carpeta

```bash
# Subir documentos PDF a GCS
gsutil cp estado_resultados.pdf gs://preavaluos-pdf/PRE-2025-001/
gsutil cp balance_general.pdf gs://preavaluos-pdf/PRE-2025-001/
gsutil cp flujo_efectivo.pdf gs://preavaluos-pdf/PRE-2025-001/
```

### 2. Trigger de Procesamiento

```bash
# Crear archivo is_ready (0 bytes, sin extensión)
# Esto activa automáticamente el procesamiento
gsutil cp /dev/null gs://preavaluos-pdf/PRE-2025-001/is_ready
```

### 3. Procesamiento Automático

El microservicio automáticamente:
1. ✅ Detecta el evento `is_ready`
2. ✅ Lista todos los PDFs en la carpeta
3. ✅ Valida cada PDF (magic bytes)
4. ✅ Clasifica con Document AI Classifier
5. ✅ Extrae datos con Document AI Extractor
6. ✅ Persiste resultados en Firestore
7. ✅ Actualiza estado del folio
8. ✅ Publica errores a DLQ si es necesario

### 4. Monitoreo

```bash
# Ver logs en tiempo real
gcloud logging tail "resource.type=cloud_run_revision AND \
  resource.labels.service_name=apolo-procesamiento-inteligente"

# Buscar por folio específico
gcloud logging read "jsonPayload.folio_id='PRE-2025-001'" \
  --limit=50 --format=json
```

### 5. Consultar Resultados

```python
from google.cloud import firestore

db = firestore.Client()

# Obtener estado del folio
folio = db.collection("folios").document("PRE-2025-001").get()
print(f"Status: {folio.get('status')}")
print(f"Total docs: {folio.get('total_docs')}")
print(f"Processed: {folio.get('processed_docs')}")

# Listar documentos procesados
docs = db.collection("folios").document("PRE-2025-001") \
  .collection("documentos").stream()

for doc in docs:
    data = doc.to_dict()
    print(f"Doc: {data.get('file_id')}")
    print(f"  Type: {data.get('doc_type')}")
    print(f"  Status: {data.get('status')}")
    
    # Ver extracciones
    extractions = doc.reference.collection("extracciones").stream()
    for ext in extractions:
        ext_data = ext.to_dict()
        print(f"  Fields: {len(ext_data.get('fields', {}))}")
```

---

## 🔧 Configuración de Document AI

### Classifier Processor

**Tipos de documentos a entrenar:**
- `ESTADO_RESULTADOS` (Estado de Resultados / Income Statement)
- `ESTADO_SITUACION_FINANCIERA` (Balance General / Balance Sheet)
- `ESTADO_FLUJOS_EFECTIVO` (Estado de Flujos de Efectivo / Cash Flow)

### Extractor Processor

**Campos a extraer (con trazabilidad):**

**Campos Generales:**
- `ORG_NAME` - Nombre de la organización
- `STATEMENT_TITLE` - Título del estado financiero
- `REPORTING_PERIOD` - Período del reporte
- `CURRENCY` - Moneda (MXN, USD, etc.)
- `UNITS_SCALE` - Escala (Miles, Millones, etc.)

**Campos de Líneas:**
- `LINE_ITEM_NAME` - Nombre del concepto
- `LINE_ITEM_VALUE` - Valor numérico
- `COLUMN_YEAR` - Año de la columna
- `SECTION_HEADER` - Encabezado de sección
- `TOTAL_LABEL` - Etiqueta de total (SUBTOTAL, TOTAL)

**Metadatos de Trazabilidad:**
- `page_refs` - Referencias de página
- `bounding_box` - Coordenadas en el documento
- `confidence` - Nivel de confianza

---

## 📊 Idempotencia y Versionamiento

### Estrategia de Idempotencia

```python
# Clave de idempotencia
doc_id = hash(folio_id + file_id + generation)

# Verificación antes de procesar
already_processed = check_firestore(doc_id)
if already_processed and status == "DONE":
    return cached_result  # No reprocesar
```

### Escenarios Cubiertos

1. ✅ **Re-entrega de evento `is_ready`**
   - Si el folio ya está en `DONE`, no se reprocesa

2. ✅ **Archivo modificado y re-subido**
   - Nuevo `generation` → nuevo `doc_id` → se procesa

3. ✅ **Falla parcial en procesamiento**
   - Solo se reproc documentos en estado != `DONE`

4. ✅ **Nueva carpeta con archivos idénticos**
   - Diferente `folio_id` → se trata como nuevo lote

---

## 🛡️ Manejo de Errores

### Niveles de Error

#### Nivel 1: Error Transitorio
- **Acción**: Retry con backoff exponencial
- **Ejemplo**: Timeout de Document AI
- **Reintentos**: Hasta 3 intentos

#### Nivel 2: Error por Documento
- **Acción**: Marcar documento como ERROR, continuar con siguiente
- **Persistencia**: Firestore + DLQ
- **Estado final**: `DONE_WITH_ERRORS`

#### Nivel 3: Error de Carpeta
- **Acción**: Detener procesamiento, marcar folio como ERROR
- **Ejemplo**: Bucket no accesible
- **Estado final**: `ERROR`

### Dead Letter Queue

```bash
# Monitorear DLQ
gcloud pubsub subscriptions pull apolo-dlq-monitor \
  --auto-ack --limit=10

# Contenido del mensaje DLQ:
{
  "folio_id": "PRE-2025-001",
  "gcs_uri": "gs://bucket/file.pdf",
  "error_type": "PROCESSING_ERROR",
  "error_message": "Document AI processor timeout",
  "attempts": 3,
  "timestamp": "2025-12-15T10:30:00Z",
  "details": {...}
}
```

---

## 🔍 Observabilidad

### Logs Estructurados

```json
{
  "event_type": "folder_processing_start",
  "folio_id": "PRE-2025-001",
  "bucket": "preavaluos-pdf",
  "folder_prefix": "PRE-2025-001/",
  "timestamp": "2025-12-15T10:00:00Z"
}
```

```json
{
  "event_type": "folder_processing_complete",
  "folio_id": "PRE-2025-001",
  "total_docs": 60,
  "successful": 58,
  "errors": 2,
  "final_status": "DONE_WITH_ERRORS",
  "timestamp": "2025-12-15T10:15:00Z"
}
```

### Métricas Clave

- **Latencia por carpeta**: tiempo desde `is_ready` hasta `DONE`
- **Throughput**: documentos procesados por minuto
- **Tasa de error**: % de documentos con ERROR
- **Uso de concurrencia**: threads activos promedio
- **Invocaciones de Document AI**: llamadas por tipo

---

## 📝 Próximos Pasos

1. **Revisar** [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) para pasos detallados de migración
2. **Configurar** Document AI processors (Classifier y Extractor)
3. **Crear** Eventarc trigger
4. **Configurar** DLQ en Pub/Sub
5. **Actualizar** service account permissions
6. **Desplegar** versión actualizada
7. **Probar** con carpeta de test

---

## 📚 Documentación Adicional

- [Migration Guide](MIGRATION_GUIDE.md) - Guía paso a paso de migración
- [Architecture](Documentation/ARCHITECTURE.md) - Arquitectura detallada
- [Deployment Guide](Documentation/DEPLOY_GUIDE.md) - Guía de despliegue
- [Firestore Schema](Documentation/FIRESTORE_SCHEMA.md) - Esquema de datos

---

## ⚙️ Configuración de Desarrollo Local

### Prueba con Simulación (sin Document AI real)

```python
# En apolo_procesamiento_inteligente_v2.py
# Comentar las integraciones reales y usar fallbacks

def classify_document(gcs_uri: str) -> Dict[str, Any]:
    # Para desarrollo: retornar clasificación simulada
    return {
        "document_type": "ESTADO_RESULTADOS",
        "confidence": 0.95,
        "classifier_version": "development"
    }
```

### Docker Compose Local

```bash
# Iniciar servicios locales
docker-compose up -d

# Ver logs
docker-compose logs -f apolo-processor
```

---

## 🆘 Soporte

Para preguntas técnicas o problemas:
- Revisar logs en Cloud Logging
- Consultar DLQ para errores recurrentes
- Contactar equipo de DevOps

**Versión**: 2.0.0 (Alineada con especificación oficial)  
**Fecha**: Diciembre 2025  
**Estado**: ✅ Production Ready (requiere configuración de Document AI)
