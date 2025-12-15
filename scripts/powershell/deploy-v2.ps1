# Script de despliegue para versión 2.0 alineada con especificación
# PowerShell version para Windows

param(
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$Region = "us-south1",
    [string]$ClassifierProcessorId = $env:CLASSIFIER_PROCESSOR_ID,
    [string]$ExtractorProcessorId = $env:EXTRACTOR_PROCESSOR_ID,
    [string]$BucketName = "preavaluos-pdf",
    [string]$DlqTopicName = "apolo-preavaluo-dlq"
)

$ErrorActionPreference = "Stop"

# Configuración
$ServiceName = "apolo-procesamiento-inteligente"
$ImageName = "gcr.io/$ProjectId/$ServiceName"
$Version = "v2.0"
$SaName = "apolo-processor-sa"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Yellow "╔═══════════════════════════════════════════════════════════╗"
Write-ColorOutput Yellow "║   Apolo Procesamiento Inteligente - Deploy v2.0          ║"
Write-ColorOutput Yellow "╚═══════════════════════════════════════════════════════════╝"
Write-Output ""

# Validar configuración
Write-ColorOutput Yellow "Validando configuración..."

if (-not $ProjectId) {
    Write-ColorOutput Red "Error: GCP_PROJECT_ID no está configurado"
    Write-Output "Ejecutar: `$env:GCP_PROJECT_ID='your-project-id'"
    exit 1
}

if (-not $ClassifierProcessorId) {
    Write-ColorOutput Yellow "Warning: CLASSIFIER_PROCESSOR_ID no está configurado"
    Write-Output "Document AI Classifier no funcionará sin este ID"
}

if (-not $ExtractorProcessorId) {
    Write-ColorOutput Yellow "Warning: EXTRACTOR_PROCESSOR_ID no está configurado"
    Write-Output "Document AI Extractor no funcionará sin este ID"
}

Write-ColorOutput Green "✓ Configuración validada"
Write-Output ""

# Paso 1: Construir imagen Docker
Write-ColorOutput Yellow "Construyendo imagen Docker..."
docker build -t "${ImageName}:${Version}" -t "${ImageName}:latest" .
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "Error construyendo imagen"
    exit 1
}
Write-ColorOutput Green "✓ Imagen construida"
Write-Output ""

# Paso 2: Push a Container Registry
Write-ColorOutput Yellow "Subiendo imagen a GCR..."
docker push "${ImageName}:${Version}"
docker push "${ImageName}:latest"
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "Error subiendo imagen"
    exit 1
}
Write-ColorOutput Green "✓ Imagen subida"
Write-Output ""

# Paso 3: Crear tópico DLQ si no existe
Write-ColorOutput Yellow "Verificando DLQ topic..."
$topicExists = gcloud pubsub topics describe $DlqTopicName --project=$ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "Creando DLQ topic..."
    gcloud pubsub topics create $DlqTopicName --project=$ProjectId
    
    # Crear suscripción para monitoreo
    gcloud pubsub subscriptions create "$DlqTopicName-monitor" `
        --topic=$DlqTopicName `
        --project=$ProjectId `
        --ack-deadline=60
    
    Write-ColorOutput Green "✓ DLQ topic creado"
} else {
    Write-ColorOutput Green "✓ DLQ topic ya existe"
}
Write-Output ""

# Paso 4: Crear service account si no existe
Write-ColorOutput Yellow "Verificando service account..."
$SaEmail = "$SaName@$ProjectId.iam.gserviceaccount.com"

$saExists = gcloud iam service-accounts describe $SaEmail --project=$ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "Creando service account..."
    gcloud iam service-accounts create $SaName `
        --display-name="Apolo Procesamiento Inteligente Service Account" `
        --project=$ProjectId
    
    Write-ColorOutput Green "✓ Service account creado"
} else {
    Write-ColorOutput Green "✓ Service account ya existe"
}
Write-Output ""

# Paso 5: Asignar permisos
Write-ColorOutput Yellow "Configurando permisos..."

$roles = @(
    "roles/storage.objectViewer",
    "roles/datastore.user",
    "roles/documentai.apiUser",
    "roles/pubsub.publisher",
    "roles/eventarc.eventReceiver"
)

foreach ($role in $roles) {
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$SaEmail" `
        --role=$role `
        --quiet | Out-Null
}

Write-ColorOutput Green "✓ Permisos configurados"
Write-Output ""

# Paso 6: Deploy Cloud Run service
Write-ColorOutput Yellow "Desplegando Cloud Run service..."

$envVars = "GCP_PROJECT_ID=$ProjectId,PROCESSOR_LOCATION=us,CLASSIFIER_PROCESSOR_ID=$ClassifierProcessorId,EXTRACTOR_PROCESSOR_ID=$ExtractorProcessorId,DLQ_TOPIC_NAME=$DlqTopicName,MAX_CONCURRENT_DOCS=8,MAX_RETRIES=3"

gcloud run deploy $ServiceName `
    --image="${ImageName}:${Version}" `
    --region=$Region `
    --platform=managed `
    --no-allow-unauthenticated `
    --service-account=$SaEmail `
    --set-env-vars=$envVars `
    --memory=2Gi `
    --timeout=900 `
    --concurrency=1 `
    --max-instances=10 `
    --min-instances=0 `
    --project=$ProjectId

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "Error desplegando Cloud Run service"
    exit 1
}

# Dar permiso de invocación
gcloud run services add-iam-policy-binding $ServiceName `
    --region=$Region `
    --member="serviceAccount:$SaEmail" `
    --role="roles/run.invoker" `
    --project=$ProjectId | Out-Null

Write-ColorOutput Green "✓ Cloud Run service desplegado"
Write-Output ""

# Paso 7: Crear Eventarc trigger
Write-ColorOutput Yellow "Configurando Eventarc trigger..."

$TriggerName = "apolo-procesamiento-trigger"

$triggerExists = gcloud eventarc triggers describe $TriggerName --location=$Region --project=$ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Output "Creando nuevo trigger..."
    gcloud eventarc triggers create $TriggerName `
        --location=$Region `
        --destination-run-service=$ServiceName `
        --destination-run-region=$Region `
        --event-filters="type=google.cloud.storage.object.v1.finalized" `
        --event-filters="bucket=$BucketName" `
        --service-account=$SaEmail `
        --project=$ProjectId
} else {
    Write-Output "Actualizando trigger existente..."
    gcloud eventarc triggers update $TriggerName `
        --location=$Region `
        --destination-run-service=$ServiceName `
        --destination-run-region=$Region `
        --project=$ProjectId
}

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "Error configurando Eventarc trigger"
    exit 1
}

Write-ColorOutput Green "✓ Eventarc trigger configurado"
Write-Output ""

# Resumen
Write-ColorOutput Green "╔═══════════════════════════════════════════════════════════╗"
Write-ColorOutput Green "║         DESPLIEGUE COMPLETADO EXITOSAMENTE               ║"
Write-ColorOutput Green "╚═══════════════════════════════════════════════════════════╝"
Write-Output ""
Write-ColorOutput Yellow "Configuración:"
Write-Output "  Project ID: $ProjectId"
Write-Output "  Region: $Region"
Write-Output "  Service: $ServiceName"
Write-Output "  Image: ${ImageName}:${Version}"
Write-Output "  Service Account: $SaEmail"
Write-Output "  Bucket: $BucketName"
Write-Output "  DLQ Topic: $DlqTopicName"
Write-Output ""
Write-ColorOutput Yellow "Para probar el servicio:"
Write-Output "  1. Subir PDFs a GCS:"
Write-Output "     gsutil cp documento.pdf gs://$BucketName/TEST-001/"
Write-Output ""
Write-Output "  2. Crear archivo is_ready:"
Write-Output "     `$null | gsutil cp - gs://$BucketName/TEST-001/is_ready"
Write-Output ""
Write-Output "  3. Monitorear logs:"
Write-Output "     gcloud logging tail `"resource.type=cloud_run_revision AND resource.labels.service_name=$ServiceName`""
Write-Output ""
Write-ColorOutput Yellow "Para verificar DLQ:"
Write-Output "  gcloud pubsub subscriptions pull $DlqTopicName-monitor --auto-ack --limit=10"
Write-Output ""

if (-not $ClassifierProcessorId -or -not $ExtractorProcessorId) {
    Write-ColorOutput Red "⚠️  IMPORTANTE: Document AI no está completamente configurado"
    Write-Output "   Configurar CLASSIFIER_PROCESSOR_ID y EXTRACTOR_PROCESSOR_ID para procesamiento real"
    Write-Output "   Sin estos IDs, el servicio usará fallbacks que no procesan documentos realmente"
}

Write-Output ""
Write-ColorOutput Green "✓ Deployment completado"
