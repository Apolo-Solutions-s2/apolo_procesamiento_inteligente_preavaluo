# 🚀 Despliegue desde Cloud Shell - Guía Rápida

Este script único está diseñado para copiarse y pegarse directamente en **Google Cloud Shell** y realizar el despliegue completo en la región de **Dallas (us-south1)** con la base de datos Firestore **apolo-preavaluos-dev**.

---

## ⚡ Inicio Rápido (3 pasos)

### 1️⃣ Abre Cloud Shell
Ve a Google Cloud Console y haz clic en el ícono de Cloud Shell (terminal) en la esquina superior derecha.

### 2️⃣ Copia el Script
Abre el archivo [`deploy-cloudshell.sh`](deploy-cloudshell.sh) y copia **TODO** su contenido.

### 3️⃣ Pega y Ejecuta
Pega el contenido completo en Cloud Shell y presiona Enter. El script hará todo automáticamente.

---

## 📋 Lo Que Hace el Script

El script realiza estas tareas en secuencia:

### ✅ Validación (PASO 0)
- Verifica que estés en Cloud Shell
- Detecta el PROJECT_ID actual
- Confirma región (us-south1 - Dallas)
- Confirma base de datos (apolo-preavaluos-dev)

### ✅ APIs de GCP (PASO 1)
Habilita todas las APIs necesarias:
- Cloud Run
- Cloud Build
- Cloud Storage
- Firestore
- Artifact Registry

### ✅ Cloud Storage (PASO 2)
- Crea bucket `preavaluos-pdf` en us-south1 (si no existe)
- Habilita versionado
- Configura política de lifecycle (90 días)

### ✅ Firestore (PASO 3)
- Crea base de datos `apolo-preavaluos-dev` en us-south1 (si no existe)
- La colección `apolo_procesamiento` se crea automáticamente al procesar el primer documento

### ✅ Código Fuente (PASO 4)
- Clona el repositorio desde GitHub
- Entra al directorio del proyecto

### ✅ Docker (PASO 5)
- Construye imagen Docker con Cloud Build
- Sube imagen a Google Container Registry
- Tag: `gcr.io/[PROJECT_ID]/apolo-procesamiento-inteligente`

### ✅ Cloud Run (PASO 6)
Despliega el servicio con:
- **Región**: us-south1 (Dallas)
- **Memoria**: 512MB
- **CPU**: 1
- **Timeout**: 300s
- **Autoscaling**: 0-10 instancias
- **Acceso**: Sin autenticación (público)

**Variables de entorno:**
- `BUCKET_NAME=preavaluos-pdf`
- `FIRESTORE_DATABASE=apolo-preavaluos-dev`
- `FIRESTORE_COLLECTION=apolo_procesamiento`

### ✅ Datos de Prueba (PASO 7)
- Crea PDFs de prueba válidos
- Los sube a GCS en carpeta `PRE-2025-TEST-001/`
- 3 archivos: balance_general.pdf, estado_resultados.pdf, registros_patronales.pdf

### ✅ Tests Automatizados (PASO 8)
Ejecuta 5 tests completos:
1. **Health Check** - Verifica que el servicio responda
2. **Procesamiento Individual** - Procesa un solo PDF
3. **Procesamiento Batch** - Procesa carpeta completa
4. **Idempotencia** - Verifica cache (from_cache: true)
5. **Manejo de Errores** - Archivo inexistente

### ✅ Verificación Firestore (PASO 9)
- Muestra comando para ver documentos procesados
- Proporciona link directo a la consola de Firestore

### ✅ Resumen Final
- URL del servicio desplegado
- Comandos útiles
- Links a consolas web
- Ejemplos de uso

---

## 🎯 Configuración Garantizada

El script **garantiza** estos valores:

| Parámetro | Valor | Configurable |
|-----------|-------|--------------|
| **Región** | `us-south1` (Dallas) | ❌ No (hardcoded) |
| **Base de datos** | `apolo-preavaluos-dev` | ❌ No (hardcoded) |
| **Colección** | `apolo_procesamiento` | ❌ No (hardcoded) |
| **Bucket** | `preavaluos-pdf` | ❌ No (hardcoded) |
| **Servicio** | `apolo-procesamiento-inteligente` | ❌ No (hardcoded) |
| **Proyecto** | Tu proyecto actual | ✅ Sí (detectado automáticamente) |

---

## 📝 Ejemplo de Ejecución

```bash
# En Cloud Shell, después de pegar el script:

================================
APOLO - DESPLIEGUE EN CLOUD SHELL
================================

✓ Proyecto detectado: mi-proyecto-123
ℹ Región: us-south1 (Dallas)
ℹ Base de datos Firestore: apolo-preavaluos-dev
ℹ Colección: apolo_procesamiento

¿Continuar con este proyecto? (s/n): s

================================
PASO 1: Habilitando APIs de GCP
================================

[PASO 1] Habilitando run.googleapis.com...
✓ run.googleapis.com habilitada
[PASO 1] Habilitando cloudbuild.googleapis.com...
✓ cloudbuild.googleapis.com habilitada
...

================================
PASO 6: Desplegando a Cloud Run
================================

[PASO 6] Desplegando servicio en us-south1...
✓ Servicio desplegado exitosamente
✓ URL del servicio: https://apolo-procesamiento-inteligente-xxxxx-uc.a.run.app

================================
PASO 8: Ejecutando pruebas
================================

[PASO 8.1] Test: Health Check
✓ Health check OK

[PASO 8.2] Test: Procesamiento Individual
Request:
{
  "folioId": "PRE-2025-TEST-001",
  "fileId": "balance_general.pdf",
  ...
}

Response:
{
  "status": "processed",
  "document_count": 1,
  ...
}
✓ Procesamiento individual OK

...

================================
RESUMEN DE DESPLIEGUE
================================

✓ ¡Despliegue completado exitosamente!
```

---

## 🔧 Después del Despliegue

### Ver Logs
```bash
gcloud run services logs read apolo-procesamiento-inteligente \
  --region=us-south1 \
  --limit=50
```

### Ver Documentos en Firestore
```bash
gcloud firestore documents list \
  --database=apolo-preavaluos-dev \
  --collection-ids=apolo_procesamiento
```

### Probar con tus Propios Documentos
```bash
# 1. Sube tus PDFs
gsutil cp mi_documento.pdf gs://preavaluos-pdf/MI-FOLIO-001/

# 2. Procesa el documento
curl -X POST "https://TU_SERVICIO.run.app" \
  -H "Content-Type: application/json" \
  -d '{
  "folioId": "MI-FOLIO-001",
  "fileId": "mi_documento.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/MI-FOLIO-001/mi_documento.pdf",
  "workflow_execution_id": "test-123"
}'
```

### Redesplegar (después de cambios)
```bash
cd apolo_procesamiento_inteligente_preavaluo

# Reconstruir y redesplegar
gcloud builds submit --tag=gcr.io/$PROJECT_ID/apolo-procesamiento-inteligente .
gcloud run deploy apolo-procesamiento-inteligente \
  --image=gcr.io/$PROJECT_ID/apolo-procesamiento-inteligente \
  --region=us-south1
```

---

## 🐛 Troubleshooting

### Error: "Project not set"
```bash
# Configura tu proyecto primero
gcloud config set project TU_PROJECT_ID

# Luego vuelve a ejecutar el script
```

### Error: "Permission denied"
Asegúrate de tener estos roles en el proyecto:
- `roles/editor` o `roles/owner`
- `roles/run.admin`
- `roles/storage.admin`
- `roles/datastore.owner`

### Error: "Firestore database already exists"
Esto es normal si la base de datos ya existía. El script continúa sin problemas.

### Servicio no responde
```bash
# Ver logs en tiempo real
gcloud run services logs tail apolo-procesamiento-inteligente \
  --region=us-south1
```

---

## 📊 Consolas Web

Después del despliegue, visita estas consolas:

### Cloud Run
```
https://console.cloud.google.com/run/detail/us-south1/apolo-procesamiento-inteligente?project=[PROJECT_ID]
```

### Firestore
```
https://console.firebase.google.com/project/[PROJECT_ID]/firestore/databases/apolo-preavaluos-dev
```

### Cloud Storage
```
https://console.cloud.google.com/storage/browser/preavaluos-pdf?project=[PROJECT_ID]
```

### Logs
```
https://console.cloud.google.com/logs/query?project=[PROJECT_ID]
```

---

## 💡 Tips

### Copiar/Pegar en Cloud Shell
1. **Selecciona TODO el contenido** del archivo `deploy-cloudshell.sh`
2. Copia con `Ctrl+C` (o `Cmd+C` en Mac)
3. En Cloud Shell, haz clic derecho → Pegar (o `Ctrl+Shift+V`)
4. Presiona `Enter`

### Monitorear el Progreso
El script muestra claramente cada paso con:
- ✓ Verde: Éxito
- ⚠ Amarillo: Advertencia (no crítico)
- ✗ Rojo: Error (detiene ejecución)
- ℹ Azul: Información

### Guardar URL del Servicio
Al final del script, copia y guarda la URL del servicio:
```
https://apolo-procesamiento-inteligente-xxxxx-uc.a.run.app
```

La necesitarás para hacer requests desde tu aplicación.

---

## 🔐 Seguridad

El servicio está configurado como **público** (`--allow-unauthenticated`) para facilitar pruebas.

**Para producción**, considera:
1. Remover `--allow-unauthenticated`
2. Usar Service Accounts con OIDC
3. Integrar con Cloud Workflows para autenticación automática

---

## 📚 Más Información

- **Documentación completa**: [`docs/`](../docs/)
- **Scripts alternativos**: [`scripts/powershell/`](powershell/) y [`scripts/bash/`](bash/)
- **Guía de testing**: [`docs/TESTING.md`](../docs/TESTING.md)
- **Estado del proyecto**: [`docs/PROJECT_STATUS.md`](../docs/PROJECT_STATUS.md)

---

## ✅ Checklist

Antes de ejecutar el script:
- [ ] Estás en Google Cloud Console
- [ ] Tienes acceso a Cloud Shell
- [ ] Tienes permisos de Editor/Owner en el proyecto
- [ ] Has seleccionado el proyecto correcto

Durante la ejecución:
- [ ] El script detectó el PROJECT_ID correcto
- [ ] Confirmaste continuar cuando se preguntó
- [ ] Todas las APIs se habilitaron correctamente
- [ ] El servicio se desplegó exitosamente
- [ ] Los tests pasaron correctamente

Después del despliegue:
- [ ] Guardaste la URL del servicio
- [ ] Verificaste los logs
- [ ] Probaste con tus propios documentos (opcional)
- [ ] Verificaste Firestore para ver documentos procesados

---

**Tiempo estimado de ejecución**: 5-7 minutos

**Última actualización**: 2025-12-04  
**Versión**: 1.0.0
