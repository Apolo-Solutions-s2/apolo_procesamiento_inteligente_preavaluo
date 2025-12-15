# ============================================================================
# Build and Push Docker Image to Artifact Registry (PowerShell)
# ============================================================================
# Script para construir y subir imagen Docker a Artifact Registry en Windows
# Uso: .\build-and-push.ps1 -Environment <environment>
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Configuración según environment
switch ($Environment) {
    "dev"  { $ProjectId = "apolo-dev-project" }
    "qa"   { $ProjectId = "apolo-qa-project" }
    "prod" { $ProjectId = "apolo-prod-project" }
}

$Region = "us-south1"
$Repository = "apolo-docker-repo"
$ImageName = "apolo-procesamiento"
$Tag = "latest"
$FullImagePath = "${Region}-docker.pkg.dev/${ProjectId}/${Repository}/${ImageName}:${Tag}"

Write-Info "Building Docker image for environment: $Environment"
Write-Info "Project: $ProjectId"
Write-Info "Image: $FullImagePath"
Write-Host ""

# Verificar que gcloud esté configurado
Write-Info "Verificando configuración de gcloud..."
$CurrentProject = gcloud config get-value project 2>$null
if ($CurrentProject -ne $ProjectId) {
    Write-Info "Cambiando proyecto a: $ProjectId"
    gcloud config set project $ProjectId
}

# Configurar Docker para Artifact Registry
Write-Info "Configurando autenticación de Docker..."
gcloud auth configure-docker "${Region}-docker.pkg.dev" --quiet

# Build de la imagen
Write-Info "Construyendo imagen Docker..."
docker build -t $FullImagePath .

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Error al construir la imagen Docker"
    exit 1
}

Write-Success "Imagen construida exitosamente"

# Push a Artifact Registry
Write-Info "Subiendo imagen a Artifact Registry..."
docker push $FullImagePath

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Error al subir la imagen a Artifact Registry"
    exit 1
}

Write-Success "Imagen subida exitosamente"
Write-Host ""
Write-Success "✓ Build completado: $FullImagePath"
Write-Host ""
Write-Info "Próximo paso:"
Write-Host "  cd infrastructure\terraform"
Write-Host "  terraform apply -var-file=`"env\$Environment.tfvars`""
