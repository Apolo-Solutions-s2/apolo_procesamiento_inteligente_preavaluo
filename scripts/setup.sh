#!/bin/bash
# ============================================================================
# Script de Configuración Inicial para Google Cloud Shell
# ============================================================================
# Configura el proyecto inicial, habilita APIs y crea recursos base
#
# Uso: ./setup.sh [PROJECT_ID]
# Ejemplo: ./setup.sh apolo-dev-project
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

PROJECT_ID=${1:-}
REGION=${GCP_REGION:-us-south1}
TF_STATE_BUCKET="apolo-tf-state-bucket"

if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Error: Debes especificar PROJECT_ID${NC}"
        echo "Uso: $0 [PROJECT_ID]"
        exit 1
    fi
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Apolo - Configuración Inicial del Proyecto     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Proyecto:${NC} $PROJECT_ID"
echo -e "${YELLOW}Región:${NC} $REGION"
echo ""

# ============================================================================
# PASO 1: Configurar Proyecto
# ============================================================================

echo -e "${BLUE}[1/4] Configurando proyecto...${NC}"

gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION

echo -e "${GREEN}✓ Proyecto configurado${NC}"

# ============================================================================
# PASO 2: Habilitar APIs Necesarias
# ============================================================================

echo -e "\n${BLUE}[2/4] Habilitando APIs de GCP...${NC}"

APIS=(
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "cloudrun.googleapis.com"
    "eventarc.googleapis.com"
    "storage.googleapis.com"
    "firestore.googleapis.com"
    "documentai.googleapis.com"
    "pubsub.googleapis.com"
    "logging.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

for API in "${APIS[@]}"; do
    echo "  Habilitando: $API"
    gcloud services enable $API --quiet
done

echo -e "${GREEN}✓ APIs habilitadas${NC}"

# ============================================================================
# PASO 3: Crear Bucket para Estado de Terraform
# ============================================================================

echo -e "\n${BLUE}[3/4] Configurando backend de Terraform...${NC}"

# Verificar si el bucket existe
if gsutil ls -b "gs://${TF_STATE_BUCKET}" &>/dev/null; then
    echo "  Bucket de estado ya existe"
else
    echo "  Creando bucket para estado de Terraform..."
    gsutil mb -p $PROJECT_ID -l $REGION "gs://${TF_STATE_BUCKET}"
    gsutil versioning set on "gs://${TF_STATE_BUCKET}"
    echo "  Bucket creado: gs://${TF_STATE_BUCKET}"
fi

echo -e "${GREEN}✓ Backend de Terraform configurado${NC}"

# ============================================================================
# PASO 4: Crear Service Account Principal
# ============================================================================

echo -e "\n${BLUE}[4/4] Creando service account...${NC}"

SA_NAME="apolo-procesamiento-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Verificar si el SA existe
if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
    echo "  Service account ya existe"
else
    echo "  Creando service account..."
    gcloud iam service-accounts create $SA_NAME \
        --display-name="Apolo Procesamiento Inteligente" \
        --description="Service account para procesamiento de documentos"
    
    # Asignar roles necesarios
    ROLES=(
        "roles/storage.objectAdmin"
        "roles/datastore.user"
        "roles/documentai.apiUser"
        "roles/logging.logWriter"
        "roles/pubsub.publisher"
    )
    
    for ROLE in "${ROLES[@]}"; do
        gcloud projects add-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="$ROLE" \
            --quiet
    done
    
    echo "  Service account creado: $SA_EMAIL"
fi

echo -e "${GREEN}✓ Service account configurado${NC}"

# ============================================================================
# RESUMEN
# ============================================================================

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Configuración Inicial Completada               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Siguiente paso:${NC}"
echo "  Ejecuta: ./deploy.sh [dev|qa|prod] $PROJECT_ID"
echo ""
