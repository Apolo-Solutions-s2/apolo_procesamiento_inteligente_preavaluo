#!/bin/bash
# Script para construir y desplegar a Cloud Run
# Uso: ./deploy-cloudrun.sh [ENVIRONMENT]
# Ejemplo: ./deploy-cloudrun.sh dev

set -e

# =========================================
# CONFIGURACIÓN
# =========================================
ENVIRONMENT=${1:-dev}
PROJECT_ID=${GCP_PROJECT_ID:-"apolo-solutions-project"}
REGION=${GCP_REGION:-"us-south1"}
SERVICE_NAME="apolo-procesamiento-inteligente"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
IMAGE_TAG="${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
BUCKET_NAME=${BUCKET_NAME:-"preavaluos-pdf"}

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Apolo - Despliegue a Cloud Run${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Entorno:${NC} ${ENVIRONMENT}"
echo -e "${YELLOW}Proyecto:${NC} ${PROJECT_ID}"
echo -e "${YELLOW}Región:${NC} ${REGION}"
echo -e "${YELLOW}Servicio:${NC} ${SERVICE_NAME}"
echo -e "${YELLOW}Imagen:${NC} ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# =========================================
# VALIDACIONES
# =========================================
echo -e "${BLUE}[1/6] Validando configuración...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI no está instalado${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado${NC}"
    exit 1
fi

# Verificar autenticación
if ! gcloud auth print-access-token &> /dev/null; then
    echo -e "${RED}Error: No estás autenticado en gcloud${NC}"
    echo "Ejecuta: gcloud auth login"
    exit 1
fi

# Configurar proyecto
gcloud config set project ${PROJECT_ID}

echo -e "${GREEN}✓ Configuración validada${NC}"
echo ""

# =========================================
# BUILD DE LA IMAGEN
# =========================================
echo -e "${BLUE}[2/6] Construyendo imagen Docker...${NC}"

# Configurar Docker para usar gcloud como credential helper
gcloud auth configure-docker gcr.io --quiet

# Construir imagen
docker build \
    --platform linux/amd64 \
    -t ${IMAGE_NAME}:${IMAGE_TAG} \
    -t ${IMAGE_NAME}:${ENVIRONMENT}-latest \
    -t ${IMAGE_NAME}:latest \
    .

echo -e "${GREEN}✓ Imagen construida exitosamente${NC}"
echo ""

# =========================================
# PUSH A GOOGLE CONTAINER REGISTRY
# =========================================
echo -e "${BLUE}[3/6] Subiendo imagen a GCR...${NC}"

docker push ${IMAGE_NAME}:${IMAGE_TAG}
docker push ${IMAGE_NAME}:${ENVIRONMENT}-latest
docker push ${IMAGE_NAME}:latest

echo -e "${GREEN}✓ Imagen subida a GCR${NC}"
echo ""

# =========================================
# DESPLIEGUE A CLOUD RUN
# =========================================
echo -e "${BLUE}[4/6] Desplegando a Cloud Run...${NC}"

gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME}:${IMAGE_TAG} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --set-env-vars BUCKET_NAME=${BUCKET_NAME} \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --concurrency 80 \
    --max-instances 10 \
    --min-instances 0 \
    --service-account apolo-procesamiento-sa@${PROJECT_ID}.iam.gserviceaccount.com

echo -e "${GREEN}✓ Servicio desplegado${NC}"
echo ""

# =========================================
# OBTENER URL DEL SERVICIO
# =========================================
echo -e "${BLUE}[5/6] Obteniendo información del servicio...${NC}"

SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --region ${REGION} \
    --format 'value(status.url)')

echo -e "${GREEN}✓ Servicio disponible en:${NC} ${SERVICE_URL}"
echo ""

# =========================================
# VERIFICACIÓN BÁSICA
# =========================================
echo -e "${BLUE}[6/6] Verificando salud del servicio...${NC}"

# Esperar un momento para que el servicio esté listo
sleep 5

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${SERVICE_URL} -X GET || echo "000")

if [ "$HTTP_STATUS" == "405" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Servicio respondiendo correctamente (HTTP ${HTTP_STATUS})${NC}"
else
    echo -e "${YELLOW}⚠ Servicio respondió con HTTP ${HTTP_STATUS}${NC}"
    echo -e "${YELLOW}  Esto puede ser normal si solo acepta POST${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Despliegue completado exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Detalles del despliegue:${NC}"
echo -e "  • Imagen: ${IMAGE_NAME}:${IMAGE_TAG}"
echo -e "  • URL: ${SERVICE_URL}"
echo -e "  • Región: ${REGION}"
echo -e "  • Entorno: ${ENVIRONMENT}"
echo ""
echo -e "${BLUE}Para probar el endpoint:${NC}"
echo "curl -X POST ${SERVICE_URL} \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"folder_prefix\": \"test/\", \"preavaluo_id\": \"PRE-2025-001\"}'"
echo ""
