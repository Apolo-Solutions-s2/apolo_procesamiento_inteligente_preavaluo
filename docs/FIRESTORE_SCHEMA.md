# 📊 Estructura Firestore para Document AI

## Visión General

El sistema ahora implementa una estructura jerárquica en Firestore que replica el patrón de **corrimientos (runs)** para organizar los resultados del procesamiento de Document AI.

---

## 🗂️ Estructura de Colecciones

```
firestore (database: apolo-preavaluos-dev)
│
└── runs/
    ├── {runId}/                          # UUID del corrimiento
    │   ├── runId: string
    │   ├── preavaluo_id: string
    │   ├── sourceBucket: string          # gs://bucket-name
    │   ├── folderPrefix: string
    │   ├── status: string                # processing | completed | partial_failure | failed
    │   ├── documentCount: number         # Total de documentos procesados
    │   ├── processedCount: number        # Documentos exitosos
    │   ├── failedCount: number           # Documentos fallidos
    │   ├── createdAt: timestamp
    │   └── updatedAt: timestamp
    │
    └── documents/                        # Subcolección
        └── {docId}/                      # Hash SHA-256(folioId:fileId)
            ├── docId: string
            ├── runId: string
            ├── folioId: string
            ├── fileId: string
            ├── gcsUri: string            # gs://bucket/path/file.pdf
            ├── status: string            # processing | completed | failed
            │
            ├── classification: {         # Resultado del Clasificador Document AI
            │   ├── documentType: string  # ESTADO_RESULTADOS | ESTADO_SITUACION_FINANCIERA | ESTADO_FLUJOS_EFECTIVO
            │   ├── confidence: number    # 0.0 - 1.0
            │   └── classifierVersion: string
            │   }
            │
            ├── extraction: {             # Resultado del Extractor Document AI
            │   ├── fields: {             # Campos estructurados por tipo de documento
            │   │   ├── ORG_NAME: string
            │   │   ├── REPORTING_PERIOD: string
            │   │   ├── CURRENCY: string
            │   │   ├── UNITS_SCALE: string
            │   │   ├── STATEMENT_TITLE: string
            │   │   └── line_items: [     # Array de líneas del documento
            │   │       {
            │   │         LINE_ITEM_NAME: string
            │   │         LINE_ITEM_VALUE: number
            │   │         COLUMN_YEAR: string
            │   │         SECTION_HEADER?: string
            │   │         TOTAL_LABEL?: string
            │   │       }
            │   │     ]
            │   │   }
            │   │
            │   └── metadata: {           # Metadata de Document AI
            │       ├── page_count: number
            │       ├── processor_version: string
            │       ├── extraction_schema_version: string
            │       ├── mime_type: string
            │       ├── decision_path: string
            │       └── table_references: [...]
            │       }
            │   }
            │
            ├── error?: {                 # Solo si status = failed
            │   ├── code: string
            │   └── message: string
            │   }
            │
            ├── processingStartedAt: timestamp
            ├── processedAt: timestamp
            ├── createdAt: timestamp
            └── updatedAt: timestamp
```

---

## 📋 Tipos de Documentos Soportados

### 1. **ESTADO_RESULTADOS** (Estado de Resultados / Profit & Loss)

**Campos extraídos:**
- `LINE_ITEM_NAME`: Ventas Netas, Costo de Ventas, Utilidad Bruta, Gastos de Operación, EBITDA, Utilidad Neta
- `LINE_ITEM_VALUE`: Valores numéricos
- `COLUMN_YEAR`: Año correspondiente
- `TOTAL_LABEL`: SUBTOTAL | TOTAL (para renglones de totales)

**Ejemplo:**
```json
{
  "ORG_NAME": "Apolo Solutions S.A. de C.V.",
  "REPORTING_PERIOD": "2024-12-31",
  "CURRENCY": "MXN",
  "UNITS_SCALE": "MILES",
  "STATEMENT_TITLE": "Estado de Resultados",
  "line_items": [
    {
      "LINE_ITEM_NAME": "Ventas Netas",
      "LINE_ITEM_VALUE": 2500000.00,
      "COLUMN_YEAR": "2024"
    },
    {
      "LINE_ITEM_NAME": "EBITDA",
      "LINE_ITEM_VALUE": 850000.00,
      "COLUMN_YEAR": "2024",
      "TOTAL_LABEL": "TOTAL"
    }
  ]
}
```

---

### 2. **ESTADO_SITUACION_FINANCIERA** (Balance General)

**Campos extraídos:**
- `LINE_ITEM_NAME`: Efectivo, Cuentas por Cobrar, Inventarios, Activo Fijo, Pasivo, Capital
- `LINE_ITEM_VALUE`: Valores numéricos
- `COLUMN_YEAR`: Año correspondiente
- `SECTION_HEADER`: ACTIVO CIRCULANTE | ACTIVO NO CIRCULANTE | PASIVO | CAPITAL
- `TOTAL_LABEL`: SUBTOTAL | TOTAL

**Ejemplo:**
```json
{
  "STATEMENT_TITLE": "Estado de Situación Financiera",
  "line_items": [
    {
      "LINE_ITEM_NAME": "Efectivo y Equivalentes",
      "LINE_ITEM_VALUE": 500000.00,
      "COLUMN_YEAR": "2024",
      "SECTION_HEADER": "ACTIVO CIRCULANTE"
    },
    {
      "LINE_ITEM_NAME": "Total Activo",
      "LINE_ITEM_VALUE": 5000000.00,
      "COLUMN_YEAR": "2024",
      "TOTAL_LABEL": "TOTAL"
    }
  ]
}
```

---

### 3. **ESTADO_FLUJOS_EFECTIVO** (Estado de Flujos de Efectivo)

**Campos extraídos:**
- `LINE_ITEM_NAME`: Flujos de Operación, Flujos de Inversión, Flujos de Financiamiento
- `LINE_ITEM_VALUE`: Valores numéricos (pueden ser negativos)
- `COLUMN_YEAR`: Año correspondiente
- `SECTION_HEADER`: ACTIVIDADES DE OPERACION | ACTIVIDADES DE INVERSION | ACTIVIDADES DE FINANCIAMIENTO
- `TOTAL_LABEL`: TOTAL

**Ejemplo:**
```json
{
  "STATEMENT_TITLE": "Estado de Flujos de Efectivo",
  "line_items": [
    {
      "LINE_ITEM_NAME": "Flujos de Operación",
      "LINE_ITEM_VALUE": 800000.00,
      "COLUMN_YEAR": "2024",
      "SECTION_HEADER": "ACTIVIDADES DE OPERACION"
    },
    {
      "LINE_ITEM_NAME": "Flujos de Inversión",
      "LINE_ITEM_VALUE": -300000.00,
      "COLUMN_YEAR": "2024",
      "SECTION_HEADER": "ACTIVIDADES DE INVERSION"
    }
  ]
}
```

---

## 🔑 Campos del Esquema Document AI

Según la especificación de Document AI, se extraen estos campos:

| Campo | Descripción | Tipo |
|-------|-------------|------|
| `LINE_ITEM_NAME` | Nombre de la cuenta en la fila | string |
| `LINE_ITEM_VALUE` | Importe asociado a esa cuenta | number |
| `COLUMN_YEAR` | Año correspondiente a una columna | string |
| `SECTION_HEADER` | Títulos que agrupan líneas | string |
| `TOTAL_LABEL` | Renglones de totales/subtotales | string |
| `CURRENCY` | Indicación de moneda | string |
| `UNITS_SCALE` | Escala (miles, millones, etc.) | string |
| `REPORTING_PERIOD` | Periodo de reporte | string |
| `ORG_NAME` | Nombre de la entidad | string |
| `STATEMENT_TITLE` | Tipo de documento | string |
| `TABLE_COLUMN_HEADER` | Encabezado de columna | array |
| `TABLE_ROW_REF` | Identificador de fila | array |
| `TABLE_CELL_REF` | Referencia a celda | string |

---

## 🔄 Flujo de Procesamiento

### 1. **Inicio del Corrimiento**
```javascript
// Se crea documento en runs/{runId}
{
  "runId": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "status": "processing",
  "documentCount": 0,
  "processedCount": 0,
  "failedCount": 0,
  "createdAt": "2025-12-04T14:00:00Z"
}
```

### 2. **Procesamiento de Documento**

**Paso 1: Validación PDF**
- Verifica magic bytes `%PDF-`
- Rechaza archivos corruptos

**Paso 2: Adquisición de Lease (Idempotencia)**
```javascript
// Se crea/actualiza en runs/{runId}/documents/{docId}
{
  "docId": "a1b2c3d4e5f6g7h8",
  "status": "processing",
  "processingStartedAt": "2025-12-04T14:00:05Z"
}
```

**Paso 3: Clasificación (Document AI)**
- Llama al clasificador
- Retorna: `document_type`, `confidence`, `classifier_version`

**Paso 4: Extracción (Document AI)**
- Llama al extractor correspondiente al tipo
- Retorna: `fields` (estructura completa) + `metadata`

**Paso 5: Persistencia**
```javascript
// Se actualiza runs/{runId}/documents/{docId}
{
  "status": "completed",
  "classification": {...},
  "extraction": {...},
  "processedAt": "2025-12-04T14:00:10Z"
}

// Se actualizan contadores en runs/{runId}
{
  "processedCount": increment(1),
  "documentCount": increment(1)
}
```

### 3. **Finalización del Corrimiento**
```javascript
// Se actualiza runs/{runId}
{
  "status": "completed",
  "documentCount": 15,
  "processedCount": 14,
  "failedCount": 1,
  "updatedAt": "2025-12-04T14:05:00Z"
}
```

---

## 🎯 Idempotencia (Cache)

El sistema implementa idempotencia robusta:

### Generación de ID Único
```python
doc_id = SHA256(f"{folioId}:{fileId}")[:16]
```

### Verificación de Cache
Si el documento ya fue procesado (`status: completed`):
1. Se retorna el resultado desde Firestore
2. Se marca en la respuesta: `from_cache: true`
3. No se vuelve a procesar

### Lease Mechanism
- Timeout: **10 minutos**
- Si un documento está en `status: processing` por más de 10 min, se permite reprocesar
- Previene procesamiento concurrente

---

## 📊 Consultas Útiles

### Obtener todos los documentos de un corrimiento
```javascript
db.collection('runs')
  .doc(runId)
  .collection('documents')
  .get()
```

### Obtener solo documentos exitosos
```javascript
db.collection('runs')
  .doc(runId)
  .collection('documents')
  .where('status', '==', 'completed')
  .get()
```

### Obtener documentos por tipo
```javascript
db.collection('runs')
  .doc(runId)
  .collection('documents')
  .where('classification.documentType', '==', 'ESTADO_RESULTADOS')
  .get()
```

### Buscar por folio (Collection Group Query)
```javascript
db.collectionGroup('documents')
  .where('folioId', '==', 'PRE-2025-001')
  .get()
```

---

## 🔐 Variables de Entorno

El código usa estas variables configurables:

```bash
# Base de datos Firestore
FIRESTORE_DATABASE=apolo-preavaluos-dev

# Colección NO SE USA (estructura jerárquica runs/documents)
# FIRESTORE_COLLECTION=apolo_procesamiento

# Bucket de GCS
BUCKET_NAME=preavaluos-pdf
```

---

## 📈 Contadores Automáticos

Los contadores se actualizan automáticamente usando `FieldValue.increment()`:

```python
run_ref.update({
    "processedCount": firestore.Increment(1),
    "documentCount": firestore.Increment(1),
    "updatedAt": firestore.SERVER_TIMESTAMP,
})
```

**Beneficios:**
- ✅ Atómico (no hay race conditions)
- ✅ Sin necesidad de leer antes de escribir
- ✅ Óptimo para concurrencia

---

## 🎨 Ejemplo Completo

### Request
```json
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001",
  "extensions": [".pdf"],
  "max_items": 500,
  "workflow_execution_id": "wf-20251204-001"
}
```

### Firestore después del procesamiento

**runs/wf-20251204-001**
```json
{
  "runId": "wf-20251204-001",
  "preavaluo_id": "PRE-2025-001",
  "sourceBucket": "gs://preavaluos-pdf",
  "folderPrefix": "PRE-2025-001/",
  "status": "completed",
  "documentCount": 3,
  "processedCount": 3,
  "failedCount": 0,
  "createdAt": "2025-12-04T14:00:00.000Z",
  "updatedAt": "2025-12-04T14:02:30.000Z"
}
```

**runs/wf-20251204-001/documents/a1b2c3d4e5f6g7h8**
```json
{
  "docId": "a1b2c3d4e5f6g7h8",
  "runId": "wf-20251204-001",
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
      "CURRENCY": "MXN",
      "UNITS_SCALE": "MILES",
      "STATEMENT_TITLE": "Estado de Situación Financiera",
      "line_items": [
        {
          "LINE_ITEM_NAME": "Efectivo y Equivalentes",
          "LINE_ITEM_VALUE": 850000.00,
          "COLUMN_YEAR": "2024",
          "SECTION_HEADER": "ACTIVO CIRCULANTE"
        },
        {
          "LINE_ITEM_NAME": "Total Activo",
          "LINE_ITEM_VALUE": 7500000.00,
          "COLUMN_YEAR": "2024",
          "TOTAL_LABEL": "TOTAL"
        }
      ]
    },
    "metadata": {
      "page_count": 2,
      "processor_version": "projects/PROJECT_ID/locations/us/processors/PROCESSOR_ID/processorVersions/VERSION_ID",
      "extraction_schema_version": "v1.0",
      "mime_type": "application/pdf",
      "decision_path": "DOCUMENT_AI"
    }
  },
  
  "processingStartedAt": "2025-12-04T14:00:05.123Z",
  "processedAt": "2025-12-04T14:00:12.456Z",
  "createdAt": "2025-12-04T14:00:05.123Z",
  "updatedAt": "2025-12-04T14:00:12.456Z"
}
```

### Response HTTP
```json
{
  "status": "processed",
  "run_id": "wf-20251204-001",
  "preavaluo_id": "PRE-2025-001",
  "bucket": "preavaluos-pdf",
  "folder_prefix": "PRE-2025-001/",
  "document_count": 3,
  "results": [
    {
      "file_name": "PRE-2025-001/balance_general.pdf",
      "gcs_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
      "classification": {
        "document_type": "ESTADO_SITUACION_FINANCIERA",
        "confidence": 0.985
      },
      "extraction": {
        "fields": {...},
        "metadata": {...}
      },
      "processed_at": "2025-12-04T14:00:12.456Z",
      "from_cache": false
    }
  ]
}
```

---

## 🚀 Próximos Pasos

### Integración Real con Document AI

Cuando integres Document AI real, reemplaza estas funciones:

```python
# simulate_classification() → 
result = documentai_client.process_document(
    name=classifier_name,
    raw_document=documentai.RawDocument(...)
)

# simulate_extraction() →
result = documentai_client.process_document(
    name=processor_name,
    raw_document=documentai.RawDocument(...)
)
```

### Agregaciones

Para calcular totales por corrimiento:
```python
# Función Cloud para calcular agregados
def calculate_run_aggregates(run_id: str):
    docs = db.collection('runs').doc(run_id).collection('documents').stream()
    
    totals = {
        'total_confidence_sum': 0,
        'document_types': {},
    }
    
    for doc in docs:
        data = doc.to_dict()
        totals['total_confidence_sum'] += data['classification']['confidence']
        doc_type = data['classification']['documentType']
        totals['document_types'][doc_type] = totals['document_types'].get(doc_type, 0) + 1
    
    # Guardar agregados
    db.collection('runs').doc(run_id).update({
        'aggregates': totals
    })
```

---

**Última actualización**: 2025-12-04  
**Versión del esquema**: 1.0.0  
**Compatible con**: Document AI v1, Firestore Native Mode
