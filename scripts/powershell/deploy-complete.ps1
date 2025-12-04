# Script Completo de Despliegue GCP
# Ejecuta este script completo después de configurar las variables

# ========================================
# CONFIGURACIÓN INICIAL
# ========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Despliegue Completo a GCP" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 🔧 CONFIGURA ESTAS VARIABLES
$PROJECT_ID = Read-Host "Ingresa tu PROJECT_ID de GCP"
if ([string]::IsNullOrWhiteSpace($PROJECT_ID)) {
    Write-Host "Error: PROJECT_ID es requerido" -ForegroundColor Red
    exit 1
}

$BUCKET_NAME = "preavaluos-pdf-${PROJECT_ID}"
$SERVICE_NAME = "apolo-procesamiento-inteligente"
$SA_NAME = "apolo-procesamiento-sa"
$REGION = "us-south1"
$IMAGE_NAME = "gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
$IMAGE_TAG = "v1.0.0"

Write-Host "Configuración:" -ForegroundColor Yellow
Write-Host "  Project ID: $PROJECT_ID"
Write-Host "  Bucket: $BUCKET_NAME"
Write-Host "  Service: $SERVICE_NAME"
Write-Host "  Region: $REGION"
Write-Host ""

$confirm = Read-Host "¿Continuar con el despliegue? (s/n)"
if ($confirm -ne "s") {
    Write-Host "Despliegue cancelado" -ForegroundColor Yellow
    exit 0
}

# ========================================
# PASO 1: Verificar gcloud CLI
# ========================================

Write-Host "`n[1/12] Verificando gcloud CLI..." -ForegroundColor Cyan

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "✗ gcloud CLI no está instalado" -ForegroundColor Red
    Write-Host "Instala desde: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

$gloudVersion = gcloud --version
Write-Host "✓ gcloud CLI instalado" -ForegroundColor Green

# ========================================
# PASO 2: Autenticación (si es necesario)
# ========================================

Write-Host "`n[2/12] Verificando autenticación..." -ForegroundColor Cyan

$authTest = gcloud auth print-access-token 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Iniciando autenticación..." -ForegroundColor Yellow
    gcloud auth login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Error en autenticación" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✓ Autenticado correctamente" -ForegroundColor Green

# ========================================
# PASO 3: Configurar Proyecto
# ========================================

Write-Host "`n[3/12] Configurando proyecto..." -ForegroundColor Cyan

gcloud config set project $PROJECT_ID
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al configurar proyecto" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Proyecto configurado: $PROJECT_ID" -ForegroundColor Green

# ========================================
# PASO 4: Habilitar APIs
# ========================================

Write-Host "`n[4/12] Habilitando APIs necesarias..." -ForegroundColor Cyan

$apis = @(
    "run.googleapis.com",
    "containerregistry.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "cloudbuild.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Habilitando $api..." -ForegroundColor Gray
    gcloud services enable $api --quiet
}

Write-Host "✓ APIs habilitadas" -ForegroundColor Green

# ========================================
# PASO 5: Crear/Verificar Bucket
# ========================================

Write-Host "`n[5/12] Configurando bucket GCS..." -ForegroundColor Cyan

$bucketExists = gsutil ls "gs://${BUCKET_NAME}" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creando bucket..." -ForegroundColor Gray
    gsutil mb -l $REGION "gs://${BUCKET_NAME}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Error al crear bucket" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Bucket creado: $BUCKET_NAME" -ForegroundColor Green
} else {
    Write-Host "✓ Bucket ya existe: $BUCKET_NAME" -ForegroundColor Green
}

# ========================================
# PASO 6: Crear Firestore
# ========================================

Write-Host "`n[6/12] Configurando Firestore..." -ForegroundColor Cyan

$firestoreCheck = gcloud firestore databases list 2>&1
if ($LASTEXITCODE -ne 0 -or $firestoreCheck -match "No databases found") {
    Write-Host "  Creando base de datos Firestore..." -ForegroundColor Gray
    gcloud firestore databases create `
        --location=$REGION `
        --type=firestore-native `
        --quiet
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Firestore creado" -ForegroundColor Green
    } else {
        Write-Host "⚠ Error al crear Firestore (puede que ya exista)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ Firestore ya configurado" -ForegroundColor Green
}

# ========================================
# PASO 7: Crear Service Account
# ========================================

Write-Host "`n[7/12] Configurando Service Account..." -ForegroundColor Cyan

$SA_EMAIL = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

$saExists = gcloud iam service-accounts describe $SA_EMAIL 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creando service account..." -ForegroundColor Gray
    
    gcloud iam service-accounts create $SA_NAME `
        --display-name="Apolo Procesamiento Service Account" `
        --description="Service account para procesar documentos" `
        --quiet
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Error al crear service account" -ForegroundColor Red
        exit 1
    }
    
    # Dar permisos
    Write-Host "  Asignando permisos..." -ForegroundColor Gray
    
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="serviceAccount:${SA_EMAIL}" `
        --role="roles/storage.objectViewer" `
        --quiet
    
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="serviceAccount:${SA_EMAIL}" `
        --role="roles/datastore.user" `
        --quiet
    
    Write-Host "✓ Service Account creado: $SA_EMAIL" -ForegroundColor Green
} else {
    Write-Host "✓ Service Account ya existe: $SA_EMAIL" -ForegroundColor Green
}

# ========================================
# PASO 8: Configurar Docker
# ========================================

Write-Host "`n[8/12] Configurando Docker para GCR..." -ForegroundColor Cyan

gcloud auth configure-docker gcr.io --quiet

Write-Host "✓ Docker configurado" -ForegroundColor Green

# ========================================
# PASO 9: Verificar Docker
# ========================================

Write-Host "`n[9/12] Verificando Docker..." -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "✗ Docker no está instalado" -ForegroundColor Red
    Write-Host "Instala Docker Desktop desde: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Docker disponible" -ForegroundColor Green

# ========================================
# PASO 10: Construir Imagen
# ========================================

Write-Host "`n[10/12] Construyendo imagen Docker..." -ForegroundColor Cyan
Write-Host "  (Esto puede tomar varios minutos)" -ForegroundColor Gray

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

# ========================================
# PASO 11: Subir Imagen a GCR
# ========================================

Write-Host "`n[11/12] Subiendo imagen a Google Container Registry..." -ForegroundColor Cyan
Write-Host "  (Esto puede tomar varios minutos)" -ForegroundColor Gray

docker push "${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${IMAGE_NAME}:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al subir imagen" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Imagen subida a GCR" -ForegroundColor Green

# ========================================
# PASO 12: Desplegar a Cloud Run
# ========================================

Write-Host "`n[12/12] Desplegando a Cloud Run..." -ForegroundColor Cyan

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
    --service-account $SA_EMAIL `
    --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error al desplegar" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Servicio desplegado exitosamente" -ForegroundColor Green

# ========================================
# OBTENER URL DEL SERVICIO
# ========================================

Write-Host "`nObteniendo información del servicio..." -ForegroundColor Cyan

$SERVICE_URL = gcloud run services describe $SERVICE_NAME `
    --region $REGION `
    --format 'value(status.url)'

# ========================================
# RESUMEN
# ========================================

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  ✓ DESPLIEGUE COMPLETADO" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Detalles del servicio:" -ForegroundColor Yellow
Write-Host "  • URL: $SERVICE_URL" -ForegroundColor White
Write-Host "  • Proyecto: $PROJECT_ID" -ForegroundColor White
Write-Host "  • Región: $REGION" -ForegroundColor White
Write-Host "  • Bucket: gs://$BUCKET_NAME" -ForegroundColor White
Write-Host "  • Service Account: $SA_EMAIL" -ForegroundColor White
Write-Host ""

Write-Host "Próximos pasos:" -ForegroundColor Cyan
Write-Host "  1. Sube archivos de prueba al bucket:" -ForegroundColor Gray
Write-Host "     gsutil cp test.pdf gs://${BUCKET_NAME}/PRE-2025-001/" -ForegroundColor White
Write-Host ""
Write-Host "  2. Prueba el servicio:" -ForegroundColor Gray
Write-Host "     .\test-cloudrun.ps1 -ServiceUrl '$SERVICE_URL' -Mode individual" -ForegroundColor White
Write-Host ""
Write-Host "  3. Ver logs:" -ForegroundColor Gray
Write-Host "     gcloud run services logs read $SERVICE_NAME --region $REGION" -ForegroundColor White
Write-Host ""

# Guardar información para uso posterior
$deployInfo = @{
    service_url = $SERVICE_URL
    project_id = $PROJECT_ID
    bucket_name = $BUCKET_NAME
    service_name = $SERVICE_NAME
    region = $REGION
    deployed_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json

$deployInfo | Out-File -FilePath "deploy-info.json" -Encoding UTF8

Write-Host "Información guardada en: deploy-info.json" -ForegroundColor Gray
Write-Host ""
