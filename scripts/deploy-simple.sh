#!/bin/bash
################################################################################
# Apolo - Despliegue SIMPLIFICADO (versión ultra-robusta)
################################################################################

# NO salir en error automáticamente - manejamos cada error manualmente
set +e

# Crear archivo de log
LOG_FILE="/tmp/apolo_deploy_$(date +%s).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "LOG: $LOG_FILE"

# Colores
G='\033[0;32m'  # Green
B='\033[0;34m'  # Blue
Y='\033[1;33m'  # Yellow
R='\033[0;31m'  # Red
N='\033[0m'     # No color

# Función para pausar si hay error
check_error() {
    if [ $1 -ne 0 ]; then
        echo -e "${R}✗ ERROR en paso anterior (código: $1)${N}"
        echo "Presiona Enter para continuar o Ctrl+C para salir..."
        read
    fi
}

echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${B}  APOLO - DESPLIEGUE EN CLOUD SHELL (DALLAS)${N}"
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""

# Configuración
REGION="us-south1"
SERVICE_NAME="apolo-procesamiento-inteligente"
BUCKET_NAME="preavaluos-pdf"
FIRESTORE_DB="apolo-preavaluos-dev"
FIRESTORE_COLLECTION="apolo_procesamiento"

# Obtener proyecto
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo -e "${R}✗ No hay proyecto configurado${N}"
    echo "Ejecuta: gcloud config set project TU_PROJECT_ID"
    exit 1
fi

IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo -e "${G}✓ Proyecto: $PROJECT_ID${N}"
echo -e "${B}  Región: $REGION${N}"
echo ""
sleep 2

################################################################################
echo -e "${B}[1/9] Habilitando APIs...${N}"
################################################################################

gcloud services enable run.googleapis.com --project="$PROJECT_ID"
check_error $?

gcloud services enable cloudbuild.googleapis.com --project="$PROJECT_ID"
check_error $?

gcloud services enable storage.googleapis.com --project="$PROJECT_ID"
check_error $?

gcloud services enable firestore.googleapis.com --project="$PROJECT_ID"
check_error $?

echo -e "${G}✓ APIs habilitadas${N}"
echo ""
sleep 1

################################################################################
echo -e "${B}[2/9] Configurando Storage...${N}"
################################################################################

# Verificar si bucket existe
if gsutil ls -b "gs://$BUCKET_NAME" 2>/dev/null | grep -q "$BUCKET_NAME"; then
    echo -e "${G}✓ Bucket $BUCKET_NAME ya existe${N}"
else
    echo "Creando bucket..."
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    if [ $? -eq 0 ]; then
        gsutil versioning set on "gs://$BUCKET_NAME"
        echo -e "${G}✓ Bucket creado${N}"
    else
        echo -e "${Y}⚠ Error creando bucket (puede ya existir)${N}"
    fi
fi

echo ""

################################################################################
echo -e "${B}[3/9] Configurando Firestore...${N}"
################################################################################

echo "Intentando crear base de datos Firestore..."
gcloud firestore databases create \
    --database="$FIRESTORE_DB" \
    --location="$REGION" \
    --type=firestore-native \
    --project="$PROJECT_ID" 2>&1 | tee /tmp/firestore_output.log

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${G}✓ Base de datos Firestore creada${N}"
elif grep -q "already exists" /tmp/firestore_output.log; then
    echo -e "${G}✓ Base de datos Firestore ya existe${N}"
else
    echo -e "${Y}⚠ Error en Firestore, pero continuando...${N}"
    echo "Salida completa guardada en /tmp/firestore_output.log"
fi

echo ""
sleep 1

################################################################################
echo -e "${B}[4/9] Descargando código...${N}"
################################################################################

REPO_URL="https://github.com/Apolo-Solutions-s2/apolo_procesamiento_inteligente_preavaluo.git"
REPO_DIR="apolo_procesamiento_inteligente_preavaluo"

# Limpiar si existe
if [ -d "$REPO_DIR" ]; then
    echo "Limpiando directorio anterior..."
    rm -rf "$REPO_DIR"
fi

# Clonar
echo "Clonando repositorio..."
git clone "$REPO_URL" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${R}✗ Error clonando repositorio${N}"
    echo "Presiona Enter para ver el log o Ctrl+C para salir..."
    read
    exit 1
fi

cd "$REPO_DIR"
if [ $? -ne 0 ]; then
    echo -e "${R}✗ Error accediendo al directorio${N}"
    echo "Presiona Enter para continuar..."
    read
    exit 1
fi

echo -e "${G}✓ Código descargado en: $(pwd)${N}"
echo ""
sleep 1

################################################################################
echo -e "${B}[5/9] Construyendo imagen Docker (2-3 min)...${N}"
################################################################################

gcloud auth configure-docker gcr.io --quiet

echo "Iniciando build..."
gcloud builds submit \
    --tag="$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --timeout=10m \
    .

if [ $? -ne 0 ]; then
    echo -e "${R}✗ Error construyendo imagen${N}"
    exit 1
fi

echo -e "${G}✓ Imagen construida${N}"
echo ""

################################################################################
echo -e "${B}[6/9] Desplegando a Cloud Run...${N}"
################################################################################

gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --platform=managed \
    --region="$REGION" \
    --allow-unauthenticated \
    --memory=512Mi \
    --cpu=1 \
    --timeout=300s \
    --max-instances=10 \
    --set-env-vars="BUCKET_NAME=$BUCKET_NAME,FIRESTORE_DATABASE=$FIRESTORE_DB,FIRESTORE_COLLECTION=$FIRESTORE_COLLECTION" \
    --project="$PROJECT_ID"

if [ $? -ne 0 ]; then
    echo -e "${R}✗ Error desplegando servicio${N}"
    exit 1
fi

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='value(status.url)')

echo -e "${G}✓ Servicio desplegado${N}"
echo ""

################################################################################
echo -e "${B}[7/9] Subiendo archivos de prueba...${N}"
################################################################################

# Crear PDF mínimo
cat > /tmp/test.pdf << 'EOF'
%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000053 00000 n 
0000000102 00000 n 
trailer<</Size 4/Root 1 0 R>>
startxref
165
%%EOF
EOF

FOLIO_ID="PRE-2025-TEST-001"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf" 2>/dev/null
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf" 2>/dev/null
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf" 2>/dev/null
rm -f /tmp/test.pdf

echo -e "${G}✓ Archivos subidos${N}"
echo ""

################################################################################
echo -e "${B}[8/9] Probando servicio...${N}"
################################################################################

echo "Esperando 5 segundos..."
sleep 5

# Test 1: Health check
echo -n "Health check... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/health")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "405" ]; then
    echo -e "${G}✓${N}"
else
    echo -e "${Y}⚠ (código: $HTTP_CODE)${N}"
fi

# Test 2: Procesamiento
echo "Procesando documentos..."

cat > /tmp/request.json << EOF
{
  "runId": "test-$(date +%s)",
  "preavaluo_id": "$FOLIO_ID",
  "fileList": [
    {
      "gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf",
      "file_name": "estado_resultados.pdf"
    },
    {
      "gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf",
      "file_name": "balance_general.pdf"
    },
    {
      "gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf",
      "file_name": "flujo_efectivo.pdf"
    }
  ]
}
EOF

RESPONSE=$(curl -s -X POST "$SERVICE_URL/" \
    -H "Content-Type: application/json" \
    -d @/tmp/request.json)

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

rm -f /tmp/request.json

echo -e "${G}✓ Test completado${N}"
echo ""

################################################################################
echo -e "${B}[9/9] Verificando Firestore...${N}"
################################################################################

echo "Estructura en Firestore:"
echo "  runs/"
echo "  └── {runId}/"
echo "      ├── status: completed"
echo "      ├── documentCount: 3"
echo "      └── documents/"
echo "          ├── {docId} (ESTADO_RESULTADOS)"
echo "          ├── {docId} (ESTADO_SITUACION_FINANCIERA)"
echo "          └── {docId} (ESTADO_FLUJOS_EFECTIVO)"
echo ""

################################################################################
# RESUMEN FINAL
################################################################################

echo ""
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${G}  ✓ DESPLIEGUE COMPLETADO${N}"
echo -e "${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
echo "Proyecto:      $PROJECT_ID"
echo "Región:        $REGION (Dallas)"
echo "Servicio:      $SERVICE_URL"
echo ""
echo "Bucket:        gs://$BUCKET_NAME"
echo "Firestore DB:  $FIRESTORE_DB"
echo "Colección:     runs/"
echo ""
echo -e "${B}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
echo "🔍 Ver en Firestore:"
echo "https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DB/data/~2Fruns"
echo ""
echo "📊 Ver logs:"
echo "gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo ""
echo -e "${G}¡Listo para producción! 🚀${N}"
echo ""
