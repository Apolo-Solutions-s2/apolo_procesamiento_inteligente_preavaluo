# Script para construir y desplegar a Cloud Run (PowerShell)
# Uso: .\deploy-cloudrun.ps1 -Environment dev
# Ejemplo: .\deploy-cloudrun.ps1 -Environment prod

param(
    [string]$Environment = "dev",
    [string]$ProjectId = $env:GCP_PROJECT_ID,
    [string]$Region = "us-south1",
    [string]$BucketName = "preavaluos-pdf"
)

# =========================================
# CONFIGURACIÓN
# =========================================
$ServiceName = "apolo-procesamiento-inteligente"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ImageName = "gcr.io/$ProjectId/$ServiceName"
$ImageTag = "$Environment-$Timestamp"

# =========================================
# FUNCIONES AUXILIARES
# =========================================
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Header($Message) {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan $Message
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
}

function Write-Step($Step, $Total, $Message) {
    Write-ColorOutput Cyan "[$Step/$Total] $Message"
}

function Write-Success($Message) {
    Write-ColorOutput Green "✓ $Message"
    Write-Output ""
}

function Write-Error($Message) {
    Write-ColorOutput Red "✗ Error: $Message"
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "⚠ $Message"
}

# =========================================
# INICIO
# =========================================
Clear-Host
Write-Header "  Apolo - Despliegue a Cloud Run"

Write-ColorOutput Yellow "Entorno: $Environment"
Write-ColorOutput Yellow "Proyecto: $ProjectId"
Write-ColorOutput Yellow "Región: $Region"
Write-ColorOutput Yellow "Servicio: $ServiceName"
Write-ColorOutput Yellow "Imagen: ${ImageName}:${ImageTag}"
Write-Output ""

# =========================================
# VALIDACIONES
# =========================================
Write-Step 1 6 "Validando configuración..."

# Verificar gcloud
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Error "gcloud CLI no está instalado"
    Write-Output "Instala desde: https://cloud.google.com/sdk/docs/install"
    exit 1
}

# Verificar Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker no está instalado"
    Write-Output "Instala desde: https://www.docker.com/products/docker-desktop"
    exit 1
}

# Verificar ProjectId
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Error "PROJECT_ID no está configurado"
    Write-Output "Define la variable de entorno GCP_PROJECT_ID o pasa -ProjectId"
    exit 1
}

# Verificar autenticación
$authTest = gcloud auth print-access-token 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "No estás autenticado en gcloud"
    Write-Output "Ejecuta: gcloud auth login"
    exit 1
}

# Configurar proyecto
gcloud config set project $ProjectId | Out-Null

Write-Success "Configuración validada"

# =========================================
# BUILD DE LA IMAGEN
# =========================================
Write-Step 2 6 "Construyendo imagen Docker..."

# Configurar Docker para usar gcloud
gcloud auth configure-docker gcr.io --quiet | Out-Null

# Construir imagen
docker build `
    --platform linux/amd64 `
    -t "${ImageName}:${ImageTag}" `
    -t "${ImageName}:${Environment}-latest" `
    -t "${ImageName}:latest" `
    .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falló la construcción de la imagen"
    exit 1
}

Write-Success "Imagen construida exitosamente"

# =========================================
# PUSH A GOOGLE CONTAINER REGISTRY
# =========================================
Write-Step 3 6 "Subiendo imagen a GCR..."

docker push "${ImageName}:${ImageTag}"
docker push "${ImageName}:${Environment}-latest"
docker push "${ImageName}:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falló la subida de la imagen"
    exit 1
}

Write-Success "Imagen subida a GCR"

# =========================================
# DESPLIEGUE A CLOUD RUN
# =========================================
Write-Step 4 6 "Desplegando a Cloud Run..."

gcloud run deploy $ServiceName `
    --image "${ImageName}:${ImageTag}" `
    --platform managed `
    --region $Region `
    --allow-unauthenticated `
    --set-env-vars BUCKET_NAME=$BucketName `
    --memory 512Mi `
    --cpu 1 `
    --timeout 300 `
    --concurrency 80 `
    --max-instances 10 `
    --min-instances 0 `
    --service-account "apolo-procesamiento-sa@${ProjectId}.iam.gserviceaccount.com"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falló el despliegue a Cloud Run"
    exit 1
}

Write-Success "Servicio desplegado"

# =========================================
# OBTENER URL DEL SERVICIO
# =========================================
Write-Step 5 6 "Obteniendo información del servicio..."

$ServiceUrl = gcloud run services describe $ServiceName `
    --region $Region `
    --format 'value(status.url)'

Write-Success "Servicio disponible en: $ServiceUrl"

# =========================================
# VERIFICACIÓN BÁSICA
# =========================================
Write-Step 6 6 "Verificando salud del servicio..."

Start-Sleep -Seconds 5

try {
    $response = Invoke-WebRequest -Uri $ServiceUrl -Method GET -ErrorAction SilentlyContinue
    $statusCode = $response.StatusCode
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
}

if ($statusCode -eq 405 -or $statusCode -eq 200) {
    Write-Success "Servicio respondiendo correctamente (HTTP $statusCode)"
} else {
    Write-Warning "Servicio respondió con HTTP $statusCode"
    Write-Warning "  Esto puede ser normal si solo acepta POST"
}

# =========================================
# RESUMEN
# =========================================
Write-Output ""
Write-Header "  Despliegue completado exitosamente"

Write-ColorOutput Yellow "Detalles del despliegue:"
Write-Output "  • Imagen: ${ImageName}:${ImageTag}"
Write-Output "  • URL: $ServiceUrl"
Write-Output "  • Región: $Region"
Write-Output "  • Entorno: $Environment"
Write-Output ""

Write-ColorOutput Cyan "Para probar el endpoint:"
Write-Output "curl -X POST $ServiceUrl ``"
Write-Output "  -H 'Content-Type: application/json' ``"
Write-Output "  -d '{`"folder_prefix`": `"test/`", `"preavaluo_id`": `"PRE-2025-001`"}'"
Write-Output ""
