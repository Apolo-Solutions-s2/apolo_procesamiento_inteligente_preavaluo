# 🚀 Guía de Despliegue en GCP

## Opción 1: Cloud Shell (Recomendado - 5 minutos)

### Paso 1: Abre Cloud Shell
1. Ve a [GCP Console](https://console.cloud.google.com)
2. Selecciona tu proyecto
3. Haz clic en el ícono de **Cloud Shell** (>_) en la parte superior derecha

### Paso 2: Copia el Script
Abre el archivo: **`scripts/deploy-cloudshell.sh`**

### Paso 3: Pega y Ejecuta
1. **Copia TODO el contenido** del archivo (583 líneas)
2. **Pega en Cloud Shell**
3. Presiona **Enter**

### Paso 4: Confirma el Despliegue
El script te pedirá confirmación:
```
Proyecto: tu-proyecto-id
Región: us-south1 (Dallas)
Servicio: apolo-procesamiento-inteligente
Bucket: preavaluos-pdf
Firestore DB: apolo-preavaluos-dev

¿Proceder con el despliegue? (y/n):
```

Escribe **`y`** y presiona Enter.

### ✅ El Script Hace TODO Automáticamente:

1. ✅ Habilita APIs necesarias (Cloud Run, Firestore, Storage, Build)
2. ✅ Crea bucket GCS `preavaluos-pdf`
3. ✅ Crea base de datos Firestore `apolo-preavaluos-dev`
4. ✅ Clona el repositorio
5. ✅ Construye la imagen Docker
6. ✅ Despliega Cloud Run en Dallas
7. ✅ Sube archivos de prueba
8. ✅ Ejecuta 5 tests automáticos
9. ✅ Muestra la URL del servicio

**Tiempo total:** ~5 minutos

---

## Opción 2: Despliegue Local con gcloud

### Pre-requisitos
```powershell
# Verifica que tengas gcloud instalado
gcloud --version

# Configura el proyecto
gcloud config set project TU_PROJECT_ID

# Autentica
gcloud auth login
```

### Paso 1: Habilita APIs
```powershell
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable storage.googleapis.com
```

### Paso 2: Crea Recursos
```powershell
# Bucket GCS
gcloud storage buckets create gs://preavaluos-pdf --location=us-south1

# Base de datos Firestore
gcloud firestore databases create --location=us-south1 --database=apolo-preavaluos-dev
```

### Paso 3: Construye la Imagen
```powershell
cd apolo_procesamiento_inteligente_preavaluo
gcloud builds submit --tag gcr.io/TU_PROJECT_ID/apolo-procesamiento-inteligente
```

### Paso 4: Despliega Cloud Run
```powershell
gcloud run deploy apolo-procesamiento-inteligente `
  --image gcr.io/TU_PROJECT_ID/apolo-procesamiento-inteligente `
  --platform managed `
  --region us-south1 `
  --allow-unauthenticated `
  --memory 1Gi `
  --timeout 540 `
  --max-instances 10 `
  --set-env-vars "BUCKET_NAME=preavaluos-pdf,FIRESTORE_DATABASE=apolo-preavaluos-dev,FIRESTORE_COLLECTION=apolo_procesamiento"
```

---

## 🧪 Cómo Probar el Servicio

### 1. Obtén la URL del Servicio
```powershell
gcloud run services describe apolo-procesamiento-inteligente --region us-south1 --format 'value(status.url)'
```

### 2. Prueba Health Check
```powershell
curl https://TU-SERVICIO-URL/health
```

Respuesta esperada:
```json
{
  "status": "ok",
  "firestore_db": "apolo-preavaluos-dev",
  "firestore_collection": "apolo_procesamiento",
  "bucket": "preavaluos-pdf"
}
```

### 3. Sube PDFs de Prueba
```powershell
# Crear PDF de prueba
echo "Estado de Resultados 2024" > estado_resultados.txt

# Subir al bucket
gcloud storage cp estado_resultados.txt gs://preavaluos-pdf/PRE-2025-001/estado_resultados.pdf
gcloud storage cp estado_resultados.txt gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf
gcloud storage cp estado_resultados.txt gs://preavaluos-pdf/PRE-2025-001/flujo_efectivo.pdf
```

### 4. Procesa un Batch (Corrimiento)
```powershell
# Guarda esto en test-request.json
@"
{
  "runId": "test-run-001",
  "preavaluo_id": "PRE-2025-001",
  "fileList": [
    {
      "gcsUri": "gs://preavaluos-pdf/PRE-2025-001/estado_resultados.pdf",
      "file_name": "estado_resultados.pdf"
    },
    {
      "gcsUri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
      "file_name": "balance_general.pdf"
    },
    {
      "gcsUri": "gs://preavaluos-pdf/PRE-2025-001/flujo_efectivo.pdf",
      "file_name": "flujo_efectivo.pdf"
    }
  ]
}
"@ | Out-File -Encoding utf8 test-request.json

# Envía la petición
curl -X POST https://TU-SERVICIO-URL/ `
  -H "Content-Type: application/json" `
  -d "@test-request.json"
```

### 5. Verifica Resultados en Firestore

#### Opción A: Desde Cloud Shell
```bash
# Ver documento de run
gcloud firestore documents get runs/test-run-001 --database=apolo-preavaluos-dev

# Ver documentos procesados
gcloud firestore documents list runs/test-run-001/documents --database=apolo-preavaluos-dev
```

#### Opción B: Desde GCP Console
1. Ve a **Firestore** en GCP Console
2. Selecciona base de datos **`apolo-preavaluos-dev`**
3. Busca la colección **`runs`**
4. Abre el documento **`test-run-001`**
5. Ve la subcolección **`documents`**

**Deberías ver:**
```
runs/
└── test-run-001/
    ├── runId: "test-run-001"
    ├── status: "completed"
    ├── documentCount: 3
    ├── processedCount: 3
    └── documents/
        ├── {docId1}/
        │   ├── classification.documentType: "ESTADO_RESULTADOS"
        │   └── extraction.fields.line_items: [...]
        ├── {docId2}/
        │   ├── classification.documentType: "ESTADO_SITUACION_FINANCIERA"
        │   └── extraction.fields.line_items: [...]
        └── {docId3}/
            ├── classification.documentType: "ESTADO_FLUJOS_EFECTIVO"
            └── extraction.fields.line_items: [...]
```

---

## 🔍 Verificar que Todo Funciona

### Test 1: Idempotencia (Cache)
```powershell
# Primera ejecución (procesa)
curl -X POST https://TU-SERVICIO-URL/ -H "Content-Type: application/json" -d "@test-request.json"

# Segunda ejecución (debe venir de cache)
curl -X POST https://TU-SERVICIO-URL/ -H "Content-Type: application/json" -d "@test-request.json"
```

**La segunda respuesta debe incluir:**
```json
{
  "results": [
    {
      "file_name": "estado_resultados.pdf",
      "from_cache": true,  // ← ¡Cache funcionando!
      "classification": {...}
    }
  ]
}
```

### Test 2: Clasificación de 3 Tipos
```powershell
# Verifica que cada PDF tenga un tipo diferente
curl https://TU-SERVICIO-URL/ -d "@test-request.json" | jq '.results[].classification.documentType'
```

**Salida esperada:**
```
"ESTADO_RESULTADOS"
"ESTADO_SITUACION_FINANCIERA"
"ESTADO_FLUJOS_EFECTIVO"
```

### Test 3: Campos Estructurados
```powershell
# Verifica que tenga line_items
curl https://TU-SERVICIO-URL/ -d "@test-request.json" | jq '.results[0].extraction.fields.line_items[0]'
```

**Salida esperada:**
```json
{
  "LINE_ITEM_NAME": "Ventas Netas",
  "LINE_ITEM_VALUE": 5000000,
  "COLUMN_YEAR": "2024",
  "SECTION_HEADER": "INGRESOS"
}
```

### Test 4: Contadores Automáticos
```bash
# En Cloud Shell
gcloud firestore documents get runs/test-run-001 --database=apolo-preavaluos-dev
```

**Debe mostrar:**
```yaml
runId: test-run-001
status: completed
documentCount: 3
processedCount: 3
failedCount: 0
```

---

## 📊 Monitoreo

### Ver Logs en Tiempo Real
```powershell
gcloud run services logs read apolo-procesamiento-inteligente --region us-south1 --limit 50
```

### Ver Métricas
```powershell
# Invocaciones
gcloud run services describe apolo-procesamiento-inteligente --region us-south1 --format 'value(status.traffic[0].latestRevision)'

# Dashboard completo
gcloud run services describe apolo-procesamiento-inteligente --region us-south1
```

### Monitorear en GCP Console
1. Ve a **Cloud Run** → **apolo-procesamiento-inteligente**
2. Pestaña **"Logs"** para ver logs en tiempo real
3. Pestaña **"Metrics"** para ver gráficas de tráfico
4. Pestaña **"Revisions"** para ver historial de despliegues

---

## 🐛 Solución de Problemas

### Error: "Service account not found"
```powershell
# Crea la cuenta de servicio
gcloud iam service-accounts create apolo-processing --display-name "Apolo Processing"

# Asigna permisos
gcloud projects add-iam-policy-binding TU_PROJECT_ID `
  --member="serviceAccount:apolo-processing@TU_PROJECT_ID.iam.gserviceaccount.com" `
  --role="roles/datastore.user"

# Redespliega con la cuenta
gcloud run deploy apolo-procesamiento-inteligente ... `
  --service-account apolo-processing@TU_PROJECT_ID.iam.gserviceaccount.com
```

### Error: "Firestore database not found"
```powershell
# Verifica que existe
gcloud firestore databases list

# Si no existe, créala
gcloud firestore databases create --location=us-south1 --database=apolo-preavaluos-dev
```

### Error: "Bucket not found"
```powershell
# Crea el bucket
gcloud storage buckets create gs://preavaluos-pdf --location=us-south1

# Verifica
gcloud storage ls gs://preavaluos-pdf/
```

### Error: "Permission denied" al escribir en Firestore
```powershell
# Da permisos a la cuenta de servicio
gcloud projects add-iam-policy-binding TU_PROJECT_ID `
  --member="serviceAccount:TU_PROJECT_NUMBER-compute@developer.gserviceaccount.com" `
  --role="roles/datastore.user"
```

---

## 📚 Documentación Adicional

- **Esquema Firestore**: [`docs/FIRESTORE_SCHEMA.md`](docs/FIRESTORE_SCHEMA.md)
- **Resumen de Cambios**: [`FIRESTORE_UPDATE_SUMMARY.md`](FIRESTORE_UPDATE_SUMMARY.md)
- **README Principal**: [`README.md`](README.md)
- **Scripts**: [`scripts/`](scripts/)

---

## ✅ Checklist Post-Despliegue

- [ ] ✅ Cloud Run desplegado en `us-south1`
- [ ] ✅ Firestore database `apolo-preavaluos-dev` creada
- [ ] ✅ Bucket `preavaluos-pdf` creado
- [ ] ✅ Health check responde OK
- [ ] ✅ Procesamiento de 3 PDFs funciona
- [ ] ✅ Cache/Idempotencia funciona (`from_cache: true`)
- [ ] ✅ 3 tipos de documentos clasificados correctamente
- [ ] ✅ Campos estructurados guardados en Firestore
- [ ] ✅ Contadores actualizados en `runs/{runId}`

---

## 🎯 Siguiente Paso: Document AI Real

Una vez que todo funcione con los **simuladores**, integra Document AI real:

1. **Crea procesadores en GCP Console**:
   - 1 Clasificador (Document AI → Create Processor → Classifier)
   - 3 Extractores (uno por tipo de documento financiero)

2. **Entrena los modelos**:
   - Sube 60 documentos de cada tipo (180 total)
   - Anota los campos requeridos
   - Entrena y despliega las versiones

3. **Actualiza el código**:
   - Reemplaza `simulate_classification()` con llamada real a Document AI
   - Reemplaza `simulate_extraction()` con llamadas a los 3 procesadores
   - Configura las variables de entorno con los IDs de procesadores

4. **Redespliega**:
   ```powershell
   gcloud run deploy ... --set-env-vars "DOCUMENTAI_CLASSIFIER_ID=projects/.../processors/..."
   ```

---

**¡Listo para desplegar! 🚀**

Para empezar ahora mismo:
1. Abre [Cloud Shell](https://console.cloud.google.com/?cloudshell=true)
2. Copia `scripts/deploy-cloudshell.sh`
3. Pega y ejecuta

El script hace todo el trabajo pesado por ti.
