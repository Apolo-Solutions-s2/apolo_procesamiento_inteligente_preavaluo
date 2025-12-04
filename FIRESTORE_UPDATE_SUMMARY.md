# ✅ RESUMEN: Actualización Firestore para Document AI

## 📋 Cambios Implementados

Se actualizó completamente la estructura de Firestore para soportar el flujo de **Document AI** con:

### 1. ✅ Estructura Jerárquica por Corrimiento (Run)

**Antes:**
```
apolo_procesamiento/
└── {docId}
```

**Ahora:**
```
runs/
└── {runId}/                    # UUID del corrimiento
    ├── metadata (status, counts, timestamps)
    └── documents/              # Subcolección
        └── {docId}/            # Cada documento procesado
```

**Beneficios:**
- ✅ Organización clara por corrimiento
- ✅ Tracking completo de cada ejecución
- ✅ Contadores automáticos (processedCount, failedCount)
- ✅ Consultas eficientes por run

---

### 2. ✅ Clasificador de 3 Tipos de Documentos

Se implementó clasificador para **estados financieros**:

| Tipo | Nombre Completo | Abreviatura |
|------|----------------|-------------|
| `ESTADO_RESULTADOS` | Estado de Resultados | P&L |
| `ESTADO_SITUACION_FINANCIERA` | Balance General | Balance Sheet |
| `ESTADO_FLUJOS_EFECTIVO` | Flujos de Efectivo | Cash Flow |

**Campos del clasificador:**
```json
{
  "documentType": "ESTADO_RESULTADOS",
  "confidence": 0.985,
  "classifierVersion": "document-ai-classifier-v1"
}
```

---

### 3. ✅ Extractores Específicos por Tipo

Cada tipo de documento tiene su extractor con campos estructurados según **Document AI**:

#### Campos Comunes (Todos los Documentos)
- `ORG_NAME` - Nombre de la organización
- `REPORTING_PERIOD` - Periodo del reporte (YYYY-MM-DD)
- `CURRENCY` - Moneda (MXN, USD, etc.)
- `UNITS_SCALE` - Escala (MILES, MILLONES, UNIDADES)
- `STATEMENT_TITLE` - Título del estado financiero

#### Campos Específicos (Line Items)
- `LINE_ITEM_NAME` - Nombre de la cuenta/concepto
- `LINE_ITEM_VALUE` - Valor numérico
- `COLUMN_YEAR` - Año de la columna
- `SECTION_HEADER` - Encabezado de sección (ACTIVO, PASIVO, etc.)
- `TOTAL_LABEL` - Indicador de total (SUBTOTAL, TOTAL)

#### Metadata de Document AI
- `processor_version` - Versión del procesador
- `extraction_schema_version` - Versión del esquema
- `page_count` - Número de páginas
- `table_references` - Referencias a tablas
- `mime_type` - Tipo de archivo

---

### 4. ✅ Idempotencia con Cache Mejorada

**Mecanismo:**
1. Se genera `docId = SHA256(folioId:fileId)[:16]`
2. Se verifica en `runs/{runId}/documents/{docId}`
3. Si existe con `status: completed` → cache hit
4. Si no existe → procesar y guardar
5. Respuesta incluye `from_cache: true/false`

**Lease Mechanism:**
- Timeout: **10 minutos**
- Previene procesamiento concurrente
- Si lease expira, permite reprocesar

**Resultado en respuesta:**
```json
{
  "file_name": "balance_general.pdf",
  "from_cache": true,  // ← Indica si vino de cache
  "classification": {...},
  "extraction": {...}
}
```

---

### 5. ✅ Contadores Automáticos

Se usan `firestore.Increment()` para actualizar contadores atómicamente:

```python
run_ref.update({
    "processedCount": firestore.Increment(1),
    "documentCount": firestore.Increment(1),
    "updatedAt": firestore.SERVER_TIMESTAMP,
})
```

**Contadores en `runs/{runId}`:**
- `documentCount` - Total de documentos procesados
- `processedCount` - Documentos exitosos
- `failedCount` - Documentos fallidos

**Beneficios:**
- ✅ Atómico (sin race conditions)
- ✅ No necesita leer antes de escribir
- ✅ Óptimo para concurrencia

---

## 📂 Estructura Completa

### Documento de Run
**Ubicación:** `runs/{runId}`

```json
{
  "runId": "wf-abc123",
  "preavaluo_id": "PRE-2025-001",
  "sourceBucket": "gs://preavaluos-pdf",
  "folderPrefix": "PRE-2025-001/",
  "status": "completed",           // processing | completed | partial_failure | failed
  "documentCount": 15,
  "processedCount": 14,
  "failedCount": 1,
  "createdAt": "2025-12-04T14:00:00Z",
  "updatedAt": "2025-12-04T14:05:00Z"
}
```

### Documento Procesado
**Ubicación:** `runs/{runId}/documents/{docId}`

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
      "processor_version": "projects/PROJECT_ID/.../VERSION_ID",
      "extraction_schema_version": "v1.0",
      "mime_type": "application/pdf",
      "decision_path": "DOCUMENT_AI"
    }
  },
  
  "processingStartedAt": "2025-12-04T14:00:05Z",
  "processedAt": "2025-12-04T14:00:12Z",
  "createdAt": "2025-12-04T14:00:05Z",
  "updatedAt": "2025-12-04T14:00:12Z"
}
```

---

## 🔍 Consultas Útiles

### Obtener todos los documentos de un corrimiento
```javascript
db.collection('runs')
  .doc('wf-abc123')
  .collection('documents')
  .get()
```

### Filtrar por tipo de documento
```javascript
db.collection('runs')
  .doc('wf-abc123')
  .collection('documents')
  .where('classification.documentType', '==', 'ESTADO_RESULTADOS')
  .get()
```

### Buscar documentos por folio (Collection Group)
```javascript
db.collectionGroup('documents')
  .where('folioId', '==', 'PRE-2025-001')
  .get()
```

### Obtener solo documentos exitosos
```javascript
db.collection('runs')
  .doc('wf-abc123')
  .collection('documents')
  .where('status', '==', 'completed')
  .get()
```

---

## 📝 Archivos Modificados

### 1. `apolo_procesamiento_inteligente.py` (ACTUALIZADO)

**Cambios:**
- ✅ Nueva función `_ensure_run_document()` - Crea documento de run
- ✅ Actualizada `_check_and_acquire_lease()` - Estructura jerárquica
- ✅ Actualizada `_persist_result()` - Guarda en runs/{runId}/documents/{docId}
- ✅ Nuevo `simulate_classification()` - 3 tipos de documentos
- ✅ Nuevo `simulate_extraction()` - Campos estructurados por tipo
- ✅ Contadores automáticos con `firestore.Increment()`
- ✅ Idempotencia con cache (`from_cache` en respuesta)

### 2. `docs/FIRESTORE_SCHEMA.md` (NUEVO)

**Contenido:**
- ✅ Documentación completa de la estructura Firestore
- ✅ Ejemplos de documentos por tipo
- ✅ Lista de campos Document AI
- ✅ Consultas útiles
- ✅ Guía de integración con Document AI real

### 3. `README.md` (ACTUALIZADO)

**Cambios:**
- ✅ Sección "Idempotencia y Firestore (Document AI)" actualizada
- ✅ Descripción de estructura jerárquica
- ✅ Clasificador de 3 tipos
- ✅ Ejemplo completo de documento en Firestore
- ✅ Link a FIRESTORE_SCHEMA.md

---

## 🚀 Próximos Pasos

### Para Integración con Document AI Real:

1. **Reemplazar Simuladores**
   ```python
   # En simulate_classification()
   result = documentai_client.process_document(
       name=classifier_name,
       raw_document=documentai.RawDocument(
           content=blob.download_as_bytes(),
           mime_type='application/pdf'
       )
   )
   
   # En simulate_extraction()
   result = documentai_client.process_document(
       name=processor_name,
       raw_document=documentai.RawDocument(...)
   )
   ```

2. **Configurar Procesadores en GCP**
   - Crear clasificador en Document AI
   - Crear 3 extractores (uno por tipo de documento)
   - Entrenar con los 180 documentos del dataset

3. **Variables de Entorno**
   ```bash
   export DOCUMENTAI_CLASSIFIER_ID="projects/.../processors/..."
   export DOCUMENTAI_PROCESSOR_ESTADO_RESULTADOS="projects/..."
   export DOCUMENTAI_PROCESSOR_SITUACION_FINANCIERA="projects/..."
   export DOCUMENTAI_PROCESSOR_FLUJOS_EFECTIVO="projects/..."
   ```

4. **Validación NIF + RAG**
   - Implementar coincidencia heurística
   - Validar datos EBITDA
   - Integrar RAG + NIF para validación

---

## ✅ Resumen de Beneficios

### Organización
- ✅ Estructura clara por corrimiento
- ✅ Tracking completo de ejecuciones
- ✅ Fácil de consultar y analizar

### Performance
- ✅ Idempotencia eficiente con cache
- ✅ Contadores atómicos sin race conditions
- ✅ Lease mechanism previene duplicados

### Escalabilidad
- ✅ Subcolecciones escalables (no hay límite de docs)
- ✅ Consultas eficientes con índices
- ✅ Collection Group queries para búsquedas globales

### Mantenibilidad
- ✅ Código estructurado y documentado
- ✅ Fácil de extender con nuevos tipos
- ✅ Compatible con Document AI real

---

## 🎯 Configuración Actual

| Parámetro | Valor |
|-----------|-------|
| **Base de datos Firestore** | `apolo-preavaluos-dev` |
| **Colección raíz** | `runs/` |
| **Subcolección** | `documents/` |
| **Región** | `us-south1` (Dallas) |
| **Bucket GCS** | `preavaluos-pdf` |

---

## 📚 Documentación

- **Esquema Firestore**: [`docs/FIRESTORE_SCHEMA.md`](docs/FIRESTORE_SCHEMA.md)
- **README Principal**: [`README.md`](README.md)
- **Guía de Despliegue**: [`docs/DEPLOY_GUIDE.md`](docs/DEPLOY_GUIDE.md)
- **Script Cloud Shell**: [`scripts/deploy-cloudshell.sh`](scripts/deploy-cloudshell.sh)

---

**Actualización completada:** 2025-12-04  
**Versión:** 2.0.0 (Document AI)  
**Compatible con:** Document AI v1, Firestore Native Mode
