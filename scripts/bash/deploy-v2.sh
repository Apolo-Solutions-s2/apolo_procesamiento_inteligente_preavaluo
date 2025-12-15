#!/bin/bash
# Script de despliegue para versión 2.0 alineada con especificación

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
PROJECT_ID="${GCP_PROJECT_ID:-}"
REGION="${REGION:-us-south1}"
SERVICE_NAME="apolo-procesamiento-inteligente"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
VERSION="v2.0"

# Validar variables requeridas
echo -e "${YELLOW}Validando configuración...${NC}"

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID no está configurado${NC}"
    echo "Ejecutar: export GCP_PROJECT_ID='your-project-id'"
    exit 1
fi

if [ -z "$CLASSIFIER_PROCESSOR_ID" ]; then
    echo -e "${YELLOW}Warning: CLASSIFIER_PROCESSOR_ID no está configurado${NC}"
    echo "Document AI Classifier no funcionará sin este ID"
fi

if [ -z "$EXTRACTOR_PROCESSOR_ID" ]; then
    echo -e "${YELLOW}Warning: EXTRACTOR_PROCESSOR_ID no está configurado${NC}"
    echo "Document AI Extractor no funcionará sin este ID"
fi

echo -e "${GREEN}✓ Configuración validada${NC}"

# Paso 1: Construir imagen Docker
echo -e "${YELLOW}Construyendo imagen Docker...${NC}"
docker build -t ${IMAGE_NAME}:${VERSION} -t ${IMAGE_NAME}:latest .
echo -e "${GREEN}✓ Imagen construida${NC}"

# Paso 2: Push a Container Registry
echo -e "${YELLOW}Subiendo imagen a GCR...${NC}"
docker push ${IMAGE_NAME}:${VERSION}
docker push ${IMAGE_NAME}:latest
echo -e "${GREEN}✓ Imagen subida${NC}"

# Paso 3: Crear tópico DLQ si no existe
echo -e "${YELLOW}Verificando DLQ topic...${NC}"
DLQ_TOPIC_NAME="${DLQ_TOPIC_NAME:-apolo-preavaluo-dlq}"

if ! gcloud pubsub topics describe ${DLQ_TOPIC_NAME} --project=${PROJECT_ID} &>/dev/null; then
    echo "Creando DLQ topic..."
    gcloud pubsub topics create ${DLQ_TOPIC_NAME} --project=${PROJECT_ID}
    
    # Crear suscripción para monitoreo
    gcloud pubsub subscriptions create ${DLQ_TOPIC_NAME}-monitor \
        --topic=${DLQ_TOPIC_NAME} \
        --project=${PROJECT_ID} \
        --ack-deadline=60
    
    echo -e "${GREEN}✓ DLQ topic creado${NC}"
else
    echo -e "${GREEN}✓ DLQ topic ya existe${NC}"
fi

# Paso 4: Crear service account si no existe
echo -e "${YELLOW}Verificando service account...${NC}"
SA_NAME="apolo-processor-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe ${SA_EMAIL} --project=${PROJECT_ID} &>/dev/null; then
    echo "Creando service account..."
    gcloud iam service-accounts create ${SA_NAME} \
        --display-name="Apolo Procesamiento Inteligente Service Account" \
        --project=${PROJECT_ID}
    
    echo -e "${GREEN}✓ Service account creado${NC}"
else
    echo -e "${GREEN}✓ Service account ya existe${NC}"
fi

# Paso 5: Asignar permisos al service account
echo -e "${YELLOW}Configurando permisos...${NC}"

# Storage
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectViewer" \
    --quiet

# Firestore
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/datastore.user" \
    --quiet

# Document AI
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/documentai.apiUser" \
    --quiet

# Pub/Sub
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/pubsub.publisher" \
    --quiet

# Eventarc
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/eventarc.eventReceiver" \
    --quiet

echo -e "${GREEN}✓ Permisos configurados${NC}"

# Paso 6: Deploy Cloud Run service
echo -e "${YELLOW}Desplegando Cloud Run service...${NC}"

gcloud run deploy ${SERVICE_NAME} \
    --image=${IMAGE_NAME}:${VERSION} \
    --region=${REGION} \
    --platform=managed \
    --no-allow-unauthenticated \
    --service-account=${SA_EMAIL} \
    --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},PROCESSOR_LOCATION=${PROCESSOR_LOCATION:-us},CLASSIFIER_PROCESSOR_ID=${CLASSIFIER_PROCESSOR_ID:-},EXTRACTOR_PROCESSOR_ID=${EXTRACTOR_PROCESSOR_ID:-},DLQ_TOPIC_NAME=${DLQ_TOPIC_NAME},MAX_CONCURRENT_DOCS=${MAX_CONCURRENT_DOCS:-8},MAX_RETRIES=${MAX_RETRIES:-3}" \
    --memory=2Gi \
    --timeout=900 \
    --concurrency=1 \
    --max-instances=10 \
    --min-instances=0 \
    --project=${PROJECT_ID}

# Dar permiso de invocación al service account
gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
    --region=${REGION} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/run.invoker" \
    --project=${PROJECT_ID}

echo -e "${GREEN}✓ Cloud Run service desplegado${NC}"

# Paso 7: Crear Eventarc trigger
echo -e "${YELLOW}Configurando Eventarc trigger...${NC}"

TRIGGER_NAME="apolo-procesamiento-trigger"
BUCKET_NAME="${BUCKET_NAME:-preavaluos-pdf}"

# Verificar si el trigger ya existe
if gcloud eventarc triggers describe ${TRIGGER_NAME} --location=${REGION} --project=${PROJECT_ID} &>/dev/null; then
    echo "Actualizando trigger existente..."
    gcloud eventarc triggers update ${TRIGGER_NAME} \
        --location=${REGION} \
        --destination-run-service=${SERVICE_NAME} \
        --destination-run-region=${REGION} \
        --project=${PROJECT_ID}
else
    echo "Creando nuevo trigger..."
    gcloud eventarc triggers create ${TRIGGER_NAME} \
        --location=${REGION} \
        --destination-run-service=${SERVICE_NAME} \
        --destination-run-region=${REGION} \
        --event-filters="type=google.cloud.storage.object.v1.finalized" \
        --event-filters="bucket=${BUCKET_NAME}" \
        --service-account=${SA_EMAIL} \
        --project=${PROJECT_ID}
fi

echo -e "${GREEN}✓ Eventarc trigger configurado${NC}"

# Resumen
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         DESPLIEGUE COMPLETADO EXITOSAMENTE               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuración:${NC}"
echo "  Project ID: ${PROJECT_ID}"
echo "  Region: ${REGION}"
echo "  Service: ${SERVICE_NAME}"
echo "  Image: ${IMAGE_NAME}:${VERSION}"
echo "  Service Account: ${SA_EMAIL}"
echo "  Bucket: ${BUCKET_NAME}"
echo "  DLQ Topic: ${DLQ_TOPIC_NAME}"
echo ""
echo -e "${YELLOW}Para probar el servicio:${NC}"
echo "  1. Subir PDFs a GCS:"
echo "     gsutil cp documento.pdf gs://${BUCKET_NAME}/TEST-001/"
echo ""
echo "  2. Crear archivo is_ready:"
echo "     gsutil cp /dev/null gs://${BUCKET_NAME}/TEST-001/is_ready"
echo ""
echo "  3. Monitorear logs:"
echo "     gcloud logging tail \"resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE_NAME}\""
echo ""
echo -e "${YELLOW}Para verificar DLQ:${NC}"
echo "  gcloud pubsub subscriptions pull ${DLQ_TOPIC_NAME}-monitor --auto-ack --limit=10"
echo ""

if [ -z "$CLASSIFIER_PROCESSOR_ID" ] || [ -z "$EXTRACTOR_PROCESSOR_ID" ]; then
    echo -e "${RED}⚠️  IMPORTANTE: Document AI no está completamente configurado${NC}"
    echo "   Configurar CLASSIFIER_PROCESSOR_ID y EXTRACTOR_PROCESSOR_ID para procesamiento real"
    echo "   Sin estos IDs, el servicio usará fallbacks que no procesan documentos realmente"
fi

echo ""
echo -e "${GREEN}✓ Deployment completado${NC}"
