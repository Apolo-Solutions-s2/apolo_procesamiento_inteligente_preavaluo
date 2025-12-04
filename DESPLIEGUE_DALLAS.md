# 🎯 GUÍA EJECUTIVA - Despliegue en Dallas con Firestore

## ⚡ Lo Más Importante

Tienes **1 script único** que hace todo el despliegue desde Cloud Shell:

📄 **`scripts/deploy-cloudshell.sh`**

---

## 🚀 Cómo Usarlo (3 Pasos)

### 1. Abre Cloud Shell
En Google Cloud Console → Haz clic en el ícono de terminal (esquina superior derecha)

### 2. Copia y Pega el Script
```bash
# Abre este archivo en tu editor:
scripts/deploy-cloudshell.sh

# Copia TODO su contenido
# Pega en Cloud Shell
# Presiona Enter
```

### 3. Sigue las Instrucciones
El script te preguntará:
- ¿Continuar con proyecto X? → Responde **s**
- ¿Eliminar directorio existente? → Responde **s** (si aparece)

**Eso es todo.** El resto es automático (5-7 minutos).

---

## ✅ Garantías del Script

El script automáticamente configura:

| Configuración | Valor Fijo |
|--------------|------------|
| **Región** | `us-south1` (Dallas, Texas) |
| **Base de datos Firestore** | `apolo-preavaluos-dev` |
| **Colección** | `apolo_procesamiento` |
| **Bucket GCS** | `preavaluos-pdf` |
| **Servicio Cloud Run** | `apolo-procesamiento-inteligente` |

**No necesitas configurar nada de esto manualmente.**

---

## 📋 Lo Que Hace el Script

### Configuración Automática
1. ✅ Habilita APIs de GCP
2. ✅ Crea bucket en Dallas
3. ✅ Crea base de datos Firestore `apolo-preavaluos-dev`
4. ✅ Clona código desde GitHub
5. ✅ Construye imagen Docker
6. ✅ Despliega a Cloud Run en Dallas

### Testing Automático
7. ✅ Sube PDFs de prueba
8. ✅ Ejecuta 5 tests completos:
   - Health check
   - Procesamiento individual
   - Procesamiento batch
   - Idempotencia (cache)
   - Manejo de errores

### Resultado
9. ✅ Te da la URL del servicio
10. ✅ Muestra comandos útiles
11. ✅ Links a consolas web

---

## 📝 Después del Despliegue

El script te dará una URL como:
```
https://apolo-procesamiento-inteligente-xxxxx-uc.a.run.app
```

**Guarda esta URL** - la necesitas para hacer requests.

### Verificar en Consolas Web

**Firestore (ver documentos procesados):**
```
https://console.firebase.google.com/project/[PROJECT_ID]/firestore/databases/apolo-preavaluos-dev
```

**Cloud Run (ver servicio):**
```
https://console.cloud.google.com/run/detail/us-south1/apolo-procesamiento-inteligente?project=[PROJECT_ID]
```

**Storage (ver PDFs):**
```
https://console.cloud.google.com/storage/browser/preavaluos-pdf?project=[PROJECT_ID]
```

---

## 🧪 Probar Tu Servicio

### 1. Sube tu PDF
```bash
gsutil cp mi_documento.pdf gs://preavaluos-pdf/MI-FOLIO-001/
```

### 2. Procésalo
```bash
curl -X POST "https://TU_SERVICIO.run.app" \
  -H "Content-Type: application/json" \
  -d '{
  "folioId": "MI-FOLIO-001",
  "fileId": "mi_documento.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/MI-FOLIO-001/mi_documento.pdf",
  "workflow_execution_id": "test-123"
}'
```

### 3. Verifica en Firestore
Los resultados se guardan automáticamente en:
- **Base de datos**: `apolo-preavaluos-dev`
- **Colección**: `apolo_procesamiento`

---

## 🔧 Comandos Útiles (Cloud Shell)

### Ver logs en tiempo real
```bash
gcloud run services logs tail apolo-procesamiento-inteligente \
  --region=us-south1
```

### Ver últimos 50 logs
```bash
gcloud run services logs read apolo-procesamiento-inteligente \
  --region=us-south1 \
  --limit=50
```

### Ver info del servicio
```bash
gcloud run services describe apolo-procesamiento-inteligente \
  --region=us-south1
```

### Ver documentos en Firestore
```bash
gcloud firestore documents list \
  --database=apolo-preavaluos-dev \
  --collection-ids=apolo_procesamiento
```

### Redesplegar (después de cambios)
```bash
cd apolo_procesamiento_inteligente_preavaluo
gcloud builds submit --tag=gcr.io/$PROJECT_ID/apolo-procesamiento-inteligente .
gcloud run deploy apolo-procesamiento-inteligente \
  --image=gcr.io/$PROJECT_ID/apolo-procesamiento-inteligente \
  --region=us-south1
```

---

## 🎯 Procesamiento Batch vs Individual

### Individual (1 documento)
```json
{
  "folioId": "PRE-2025-001",
  "fileId": "balance.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance.pdf",
  "workflow_execution_id": "run-123"
}
```

### Batch (carpeta completa)
```json
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001",
  "extensions": [".pdf"],
  "max_items": 500,
  "workflow_execution_id": "run-batch-123"
}
```

**El servicio procesa todos los PDFs en la carpeta automáticamente.**

---

## 📊 Estructura de Respuesta

### Éxito
```json
{
  "status": "processed",
  "preavaluo_id": "PRE-2025-001",
  "document_count": 3,
  "results": [
    {
      "file_name": "balance_general.pdf",
      "gcs_uri": "gs://...",
      "classification": {
        "document_type": "BalanceGeneral",
        "confidence": 0.95
      },
      "extraction": {
        "fields": {...},
        "metadata": {...}
      },
      "processed_at": "2025-12-04T14:30:00Z",
      "from_cache": false
    }
  ]
}
```

### Error
```json
{
  "status": "error",
  "error": {
    "stage": "VALIDATION",
    "code": "NO_VALID_PDFS",
    "message": "No valid PDF files found.",
    "details": {...}
  }
}
```

---

## 🔐 Base de Datos Firestore

### Estructura de Documentos

**Base de datos**: `apolo-preavaluos-dev`  
**Colección**: `apolo_procesamiento`  
**Document ID**: Hash SHA-256 de `folioId:fileId` (16 caracteres)

### Campos Guardados
```json
{
  "doc_id": "a1b2c3d4e5f6g7h8",
  "folio_id": "PRE-2025-001",
  "file_id": "balance_general.pdf",
  "gcs_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
  "run_id": "wf-abc123",
  "status": "completed",
  "classification": {...},
  "extraction": {...},
  "processing_started_at": "2025-12-04T14:30:00Z",
  "processed_at": "2025-12-04T14:30:05Z",
  "updated_at": "2025-12-04T14:30:05Z"
}
```

### Idempotencia
- Si re-procesas el mismo documento → usa cache
- Respuesta incluye `"from_cache": true`
- Previene procesamiento duplicado

---

## ⚠️ Requisitos Previos

✅ Tener acceso a un proyecto GCP  
✅ Permisos de Editor/Owner en el proyecto  
✅ No necesitas instalar nada (Cloud Shell tiene todo)

---

## 🐛 Problemas Comunes

### "Project not set"
```bash
gcloud config set project TU_PROJECT_ID
# Luego vuelve a ejecutar el script
```

### "Permission denied"
Necesitas estos roles:
- `roles/editor` o `roles/owner`
- `roles/run.admin`
- `roles/storage.admin`
- `roles/datastore.owner`

### Servicio no responde
```bash
# Ver logs
gcloud run services logs tail apolo-procesamiento-inteligente --region=us-south1
```

---

## 📚 Documentación Completa

Si necesitas más detalles:

- **Guía Cloud Shell**: [`scripts/CLOUDSHELL_DEPLOY.md`](scripts/CLOUDSHELL_DEPLOY.md)
- **Inicio Rápido**: [`docs/QUICKSTART.md`](docs/QUICKSTART.md)
- **Guía de Pruebas**: [`docs/TESTING.md`](docs/TESTING.md)
- **Scripts Alternativos**: [`scripts/README.md`](scripts/README.md)

---

## ✅ Checklist Rápido

**Antes:**
- [ ] Estoy en Google Cloud Console
- [ ] Tengo Cloud Shell abierto
- [ ] Tengo permisos de Editor/Owner

**Durante:**
- [ ] Copié TODO el script `deploy-cloudshell.sh`
- [ ] Pegué en Cloud Shell
- [ ] Confirmé el proyecto cuando preguntó

**Después:**
- [ ] Guardé la URL del servicio
- [ ] Verifiqué Firestore (base de datos: apolo-preavaluos-dev)
- [ ] Probé con mis propios PDFs

---

## 🎉 Resumen

**Un solo script** hace todo:
- ✅ Despliega en Dallas (us-south1)
- ✅ Usa base de datos apolo-preavaluos-dev
- ✅ Crea colección apolo_procesamiento
- ✅ Ejecuta tests automáticamente
- ✅ Te da URL del servicio

**Tiempo total**: 5-7 minutos

**Costo**: ~$0 para pruebas (free tier)

---

📄 **Script**: [`scripts/deploy-cloudshell.sh`](scripts/deploy-cloudshell.sh)  
📖 **Guía Completa**: [`scripts/CLOUDSHELL_DEPLOY.md`](scripts/CLOUDSHELL_DEPLOY.md)

**¡Listo para copiar y pegar en Cloud Shell!** 🚀
