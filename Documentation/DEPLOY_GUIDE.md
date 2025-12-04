# 🚀 Guía de Despliegue GCP - Paso a Paso

Esta guía te llevará desde cero hasta tener tu microservicio funcionando en Cloud Run.

## 📋 Pre-requisitos

Antes de comenzar, necesitas:
- [ ] Cuenta de Google Cloud Platform (GCP)
- [ ] Un proyecto de GCP creado
- [ ] Facturación habilitada en el proyecto
- [ ] gcloud CLI instalado (lo instalaremos si no lo tienes)

## 🔧 Paso 1: Instalar Google Cloud SDK

### Windows (PowerShell)
```powershell
# Descargar instalador
Invoke-WebRequest -Uri https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe -OutFile "$env:TEMP\GoogleCloudSDKInstaller.exe"

# Ejecutar instalador
Start-Process -FilePath "$env:TEMP\GoogleCloudSDKInstaller.exe" -Wait

# Reiniciar PowerShell después de la instalación
```

### Verificar instalación
```powershell
gcloud --version
```

## 🔐 Paso 2: Autenticación en GCP

```powershell
# Autenticarte con tu cuenta de Google
gcloud auth login

# Esto abrirá un navegador para que inicies sesión
# Sigue las instrucciones en el navegador
```

## 📦 Paso 3: Configurar tu Proyecto GCP

```powershell
# Listar proyectos disponibles
gcloud projects list

# Configurar el proyecto que usarás
# Reemplaza TU_PROJECT_ID con el ID de tu proyecto
$PROJECT_ID = "TU_PROJECT_ID"
gcloud config set project $PROJECT_ID

# Verificar configuración
gcloud config get-value project
```

## 🔑 Paso 4: Habilitar APIs Necesarias

```powershell
# Habilitar Cloud Run API
gcloud services enable run.googleapis.com

# Habilitar Container Registry API
gcloud services enable containerregistry.googleapis.com

# Habilitar Cloud Storage API (para el bucket)
gcloud services enable storage.googleapis.com

# Habilitar Firestore API (para persistencia)
gcloud services enable firestore.googleapis.com

# Habilitar Cloud Build API (para construir imágenes)
gcloud services enable cloudbuild.googleapis.com

Write-Host "✓ APIs habilitadas" -ForegroundColor Green
```

## 🪣 Paso 5: Crear Bucket de GCS (si no existe)

```powershell
# Nombre del bucket (debe ser único globalmente)
$BUCKET_NAME = "preavaluos-pdf-$PROJECT_ID"

# Crear bucket
gsutil mb -l us-south1 gs://$BUCKET_NAME

# O verificar si ya existe
gsutil ls gs://$BUCKET_NAME

Write-Host "✓ Bucket configurado: $BUCKET_NAME" -ForegroundColor Green
```

## 📄 Paso 6: Crear Base de Datos Firestore

```powershell
# Crear base de datos Firestore (modo Native)
gcloud firestore databases create `
  --location=us-south1 `
  --type=firestore-native

Write-Host "✓ Firestore creado" -ForegroundColor Green
```

## 👤 Paso 7: Crear Service Account

```powershell
# Nombre del service account
$SA_NAME = "apolo-procesamiento-sa"
$SA_EMAIL = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Crear service account
gcloud iam service-accounts create $SA_NAME `
  --display-name="Apolo Procesamiento Service Account" `
  --description="Service account para procesar documentos"

# Dar permisos de Storage
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:${SA_EMAIL}" `
  --role="roles/storage.objectViewer"

# Dar permisos de Firestore
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:${SA_EMAIL}" `
  --role="roles/datastore.user"

Write-Host "✓ Service Account creado: $SA_EMAIL" -ForegroundColor Green
```

## 🐳 Paso 8: Configurar Docker para GCP

```powershell
# Configurar Docker para usar gcloud como credential helper
gcloud auth configure-docker gcr.io

Write-Host "✓ Docker configurado para GCR" -ForegroundColor Green
```

## 🏗️ Paso 9: Construir y Subir Imagen

```powershell
# Navegar al directorio del proyecto (si no estás ahí)
cd "c:\Users\LD_51\Desktop\job\Sarah\apolo_procesamiento_inteligente_preavaluo"

# Variables
$SERVICE_NAME = "apolo-procesamiento-inteligente"
$IMAGE_NAME = "gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
$IMAGE_TAG = "v1.0.0"

Write-Host "`n🔨 Construyendo imagen Docker..." -ForegroundColor Cyan

# Construir imagen
docker build `
  --platform linux/amd64 `
  -t "${IMAGE_NAME}:${IMAGE_TAG}" `
  -t "${IMAGE_NAME}:latest" `
  .

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al construir imagen" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Imagen construida" -ForegroundColor Green

Write-Host "`n📤 Subiendo imagen a GCR..." -ForegroundColor Cyan

# Push a Google Container Registry
docker push "${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${IMAGE_NAME}:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al subir imagen" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Imagen subida a GCR" -ForegroundColor Green
```

## 🚀 Paso 10: Desplegar a Cloud Run

```powershell
$REGION = "us-south1"

Write-Host "`n🚀 Desplegando a Cloud Run..." -ForegroundColor Cyan

gcloud run deploy $SERVICE_NAME `
  --image "${IMAGE_NAME}:${IMAGE_TAG}" `
  --platform managed `
  --region $REGION `
  --allow-unauthenticated `
  --set-env-vars BUCKET_NAME=$BUCKET_NAME `
  --memory 512Mi `
  --cpu 1 `
  --timeout 300 `
  --concurrency 80 `
  --max-instances 10 `
  --min-instances 0 `
  --service-account $SA_EMAIL

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al desplegar" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Servicio desplegado" -ForegroundColor Green
```

## 🔍 Paso 11: Obtener URL del Servicio

```powershell
$SERVICE_URL = gcloud run services describe $SERVICE_NAME `
  --region $REGION `
  --format 'value(status.url)'

Write-Host "`n✓ Servicio disponible en:" -ForegroundColor Green
Write-Host $SERVICE_URL -ForegroundColor Cyan
```

## 📤 Paso 12: Subir Archivos de Prueba

```powershell
# Crear carpeta de prueba
$TEST_FOLDER = "PRE-2025-001"

# Subir un PDF de prueba (necesitas tener uno)
# Opción 1: Si tienes un PDF
# gsutil cp "ruta/a/tu/archivo.pdf" "gs://${BUCKET_NAME}/${TEST_FOLDER}/balance_general.pdf"

# Opción 2: Crear un archivo dummy para probar
$dummyContent = "%PDF-1.4`n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj`nxref`n0 4`n0000000000 65535 f`n0000000009 00000 n`n0000000056 00000 n`n0000000114 00000 n`ntrailer<</Size 4/Root 1 0 R>>`nstartxref`n190`n%%EOF"
$dummyContent | Out-File -FilePath "test-dummy.pdf" -Encoding ASCII

gsutil cp test-dummy.pdf "gs://${BUCKET_NAME}/${TEST_FOLDER}/balance_general.pdf"

Write-Host "✓ Archivo de prueba subido" -ForegroundColor Green
```

## 🧪 Paso 13: Probar el Servicio

```powershell
Write-Host "`n🧪 Probando servicio..." -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "`nTest 1: Health Check" -ForegroundColor Yellow
$healthResponse = Invoke-WebRequest -Uri $SERVICE_URL -Method GET -ErrorAction SilentlyContinue
Write-Host "Status: $($healthResponse.StatusCode)" -ForegroundColor Cyan

# Test 2: Procesamiento Individual
Write-Host "`nTest 2: Procesamiento Individual" -ForegroundColor Yellow

$body = @{
    folioId = "PRE-2025-001"
    fileId = "balance_general.pdf"
    gcs_pdf_uri = "gs://${BUCKET_NAME}/PRE-2025-001/balance_general.pdf"
    workflow_execution_id = "test-$(Get-Date -Format 'yyyyMMddHHmmss')"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $SERVICE_URL -Method POST `
    -ContentType "application/json" `
    -Body $body

Write-Host "Response:" -ForegroundColor Gray
$response | ConvertTo-Json -Depth 10

if ($response.status -eq "processed" -or $response.status -eq "no_files") {
    Write-Host "✓ Test exitoso: $($response.status)" -ForegroundColor Green
    Write-Host "Documentos procesados: $($response.document_count)" -ForegroundColor Cyan
} elseif ($response.status -eq "error") {
    Write-Host "⚠ Error en test: $($response.error.message)" -ForegroundColor Yellow
}

# Test 3: Procesamiento Batch
Write-Host "`nTest 3: Procesamiento Batch" -ForegroundColor Yellow

$batchBody = @{
    folder_prefix = "PRE-2025-001/"
    preavaluo_id = "PRE-2025-001"
    extensions = @(".pdf")
    max_items = 10
    workflow_execution_id = "test-batch-$(Get-Date -Format 'yyyyMMddHHmmss')"
} | ConvertTo-Json

$batchResponse = Invoke-RestMethod -Uri $SERVICE_URL -Method POST `
    -ContentType "application/json" `
    -Body $batchBody

Write-Host "Response:" -ForegroundColor Gray
$batchResponse | ConvertTo-Json -Depth 10

if ($batchResponse.status -eq "processed" -or $batchResponse.status -eq "no_files") {
    Write-Host "✓ Test exitoso: $($batchResponse.status)" -ForegroundColor Green
    Write-Host "Documentos procesados: $($batchResponse.document_count)" -ForegroundColor Cyan
}
```

## 📊 Paso 14: Ver Logs

```powershell
# Ver logs en tiempo real
Write-Host "`n📊 Mostrando logs (Ctrl+C para salir)..." -ForegroundColor Cyan

gcloud run services logs read $SERVICE_NAME `
  --region $REGION `
  --limit 50 `
  --format json | ConvertFrom-Json | Format-Table -Property timestamp, textPayload -AutoSize
```

## 🎉 ¡Listo!

Tu servicio está desplegado y funcionando. Puedes:

1. **Ver el servicio en la consola:**
   https://console.cloud.google.com/run?project=$PROJECT_ID

2. **Monitorear logs:**
   https://console.cloud.google.com/logs/query?project=$PROJECT_ID

3. **Ver el bucket:**
   https://console.cloud.google.com/storage/browser/$BUCKET_NAME?project=$PROJECT_ID

## 🔄 Comandos Útiles

### Actualizar servicio después de cambios
```powershell
# Reconstruir y redesplegar
docker build -t "${IMAGE_NAME}:latest" .
docker push "${IMAGE_NAME}:latest"
gcloud run deploy $SERVICE_NAME --image "${IMAGE_NAME}:latest" --region $REGION
```

### Ver información del servicio
```powershell
gcloud run services describe $SERVICE_NAME --region $REGION
```

### Eliminar servicio (cuando ya no lo necesites)
```powershell
gcloud run services delete $SERVICE_NAME --region $REGION
```

### Limpiar recursos
```powershell
# Eliminar service account
gcloud iam service-accounts delete $SA_EMAIL --quiet

# Eliminar bucket
gsutil -m rm -r gs://$BUCKET_NAME

# Eliminar imágenes
gcloud container images delete "${IMAGE_NAME}:latest" --quiet
```

---

**Variables para copiar:**
```powershell
$PROJECT_ID = "TU_PROJECT_ID"
$BUCKET_NAME = "preavaluos-pdf-$PROJECT_ID"
$SERVICE_NAME = "apolo-procesamiento-inteligente"
$SA_NAME = "apolo-procesamiento-sa"
$REGION = "us-south1"
$IMAGE_NAME = "gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
```
