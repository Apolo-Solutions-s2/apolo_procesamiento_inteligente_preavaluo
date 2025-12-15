#!/bin/bash
# ============================================================================
# Script de Despliegue Completo para Google Cloud Shell
# ============================================================================
# Este script despliega la infraestructura completa usando Terraform
# y despliega el servicio Cloud Run
#
# Uso: ./deploy.sh [ENVIRONMENT] [PROJECT_ID]
# Ejemplo: ./deploy.sh dev apolo-dev-project
# ============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

ENVIRONMENT=${1:-dev}
PROJECT_ID=${2:-}
REGION=${GCP_REGION:-us-south1}
SERVICE_NAME="apolo-procesamiento-inteligente"

if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Error: Debes especificar PROJECT_ID${NC}"
        echo "Uso: $0 [ENVIRONMENT] [PROJECT_ID]"
        exit 1
    fi
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Apolo - Despliegue Completo (Google Cloud Shell)   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuración:${NC}"
echo "  • Entorno: $ENVIRONMENT"
echo "  • Proyecto: $PROJECT_ID"
echo "  • Región: $REGION"
echo ""

read -p "¿Continuar con el despliegue? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Despliegue cancelado"
    exit 0
fi

# ============================================================================
# PASO 1: Configurar Proyecto
# ============================================================================

echo -e "\n${BLUE}[1/5] Configurando proyecto GCP...${NC}"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION

echo -e "${GREEN}✓ Proyecto configurado${NC}"

# ============================================================================
# PASO 2: Construir y Subir Imagen Docker
# ============================================================================

echo -e "\n${BLUE}[2/5] Construyendo y subiendo imagen Docker...${NC}"

IMAGE_TAG="$ENVIRONMENT-$(date +%Y%m%d-%H%M%S)"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:${IMAGE_TAG}"

# Configurar Docker para GCR
gcloud auth configure-docker gcr.io --quiet

# Construir usando Cloud Build (más rápido en Cloud Shell)
gcloud builds submit \
    --tag ${IMAGE_NAME} \
    --timeout=600s \
    .

echo -e "${GREEN}✓ Imagen construida y subida: ${IMAGE_NAME}${NC}"

# ============================================================================
# PASO 3: Desplegar Infraestructura con Terraform
# ============================================================================

echo -e "\n${BLUE}[3/5] Desplegando infraestructura Terraform...${NC}"

cd infrastructure/terraform

# Inicializar Terraform si es necesario
if [ ! -d ".terraform" ]; then
    echo "Inicializando Terraform..."
    terraform init
fi

# Aplicar configuración
terraform apply \
    -var-file="env/${ENVIRONMENT}.tfvars" \
    -var="project_id=${PROJECT_ID}" \
    -var="cloudrun_image=${IMAGE_NAME}" \
    -auto-approve

echo -e "${GREEN}✓ Infraestructura desplegada${NC}"

cd ../..

# ============================================================================
# PASO 4: Verificar Despliegue
# ============================================================================

echo -e "\n${BLUE}[4/5] Verificando despliegue...${NC}"

SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --region ${REGION} \
    --format 'value(status.url)' 2>/dev/null || echo "")

if [ -n "$SERVICE_URL" ]; then
    echo -e "${GREEN}✓ Servicio desplegado: ${SERVICE_URL}${NC}"
else
    echo -e "${YELLOW}⚠ No se pudo obtener URL del servicio${NC}"
fi

# ============================================================================
# PASO 5: Configurar Eventarc (si aplica)
# ============================================================================

echo -e "\n${BLUE}[5/5] Verificando configuración Eventarc...${NC}"

BUCKET_NAME="apolo-preavaluos-pdf-${ENVIRONMENT}"
TRIGGER_NAME="apolo-gcs-trigger-${ENVIRONMENT}"

# Verificar si el trigger existe
if gcloud eventarc triggers describe $TRIGGER_NAME --location=$REGION &>/dev/null; then
    echo -e "${GREEN}✓ Trigger Eventarc configurado${NC}"
else
    echo -e "${YELLOW}⚠ Trigger Eventarc no encontrado (puede ser normal)${NC}"
fi

# ============================================================================
# RESUMEN
# ============================================================================

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Despliegue Completado Exitosamente         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Recursos desplegados:${NC}"
echo "  • Cloud Run: $SERVICE_NAME"
echo "  • Bucket: $BUCKET_NAME"
echo "  • Imagen: $IMAGE_NAME"
[ -n "$SERVICE_URL" ] && echo "  • URL: $SERVICE_URL"
echo ""
echo -e "${BLUE}Siguiente paso:${NC}"
echo "  Sube archivos PDF a gs://${BUCKET_NAME}/ para procesarlos"
echo ""
