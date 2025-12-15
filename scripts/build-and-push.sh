#!/bin/bash
# ============================================================================
# Build and Push Docker Image to Artifact Registry
# ============================================================================
# Script para construir y subir imagen Docker a Artifact Registry
# Uso: ./build-and-push.sh <environment>
# ============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validar argumentos
if [ $# -lt 1 ]; then
    log_error "Uso: $0 <environment>"
    echo ""
    echo "Environments: dev, qa, prod"
    echo ""
    echo "Ejemplo:"
    echo "  $0 dev     # Build y push para dev"
    echo "  $0 prod    # Build y push para prod"
    exit 1
fi

ENV=$1

# Validar environment
if [[ ! "$ENV" =~ ^(dev|qa|prod)$ ]]; then
    log_error "Environment inválido: $ENV"
    log_error "Environments válidos: dev, qa, prod"
    exit 1
fi

# Configuración según environment
case $ENV in
    dev)
        PROJECT_ID="apolo-dev-project"
        ;;
    qa)
        PROJECT_ID="apolo-qa-project"
        ;;
    prod)
        PROJECT_ID="apolo-prod-project"
        ;;
esac

REGION="us-south1"
REPOSITORY="apolo-docker-repo"
IMAGE_NAME="apolo-procesamiento"
TAG="latest"
FULL_IMAGE_PATH="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${TAG}"

log_info "Building Docker image for environment: $ENV"
log_info "Project: $PROJECT_ID"
log_info "Image: $FULL_IMAGE_PATH"
echo ""

# Verificar que gcloud esté configurado
log_info "Verificando configuración de gcloud..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    log_info "Cambiando proyecto a: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
fi

# Configurar Docker para Artifact Registry
log_info "Configurando autenticación de Docker..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

# Build de la imagen
log_info "Construyendo imagen Docker..."
docker build -t $FULL_IMAGE_PATH .

if [ $? -ne 0 ]; then
    log_error "Error al construir la imagen Docker"
    exit 1
fi

log_success "Imagen construida exitosamente"

# Push a Artifact Registry
log_info "Subiendo imagen a Artifact Registry..."
docker push $FULL_IMAGE_PATH

if [ $? -ne 0 ]; then
    log_error "Error al subir la imagen a Artifact Registry"
    exit 1
fi

log_success "Imagen subida exitosamente"
echo ""
log_success "✓ Build completado: $FULL_IMAGE_PATH"
echo ""
log_info "Próximo paso:"
echo "  cd infrastructure/terraform"
echo "  terraform apply -var-file=\"env/${ENV}.tfvars\""
