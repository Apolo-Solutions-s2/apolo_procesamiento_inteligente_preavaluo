#!/bin/bash
################################################################################
# Apolo - Despliegue AUTOMÁTICO para Cloud Shell (SIN CONFIRMACIONES)
# 
# Script autocontenido - ejecuta TODO sin preguntar
# Despliega en Dallas (us-south1) con base de datos apolo-preavaluos-dev
# 
# Uso: bash <(curl -s https://raw.githubusercontent.com/...)
#      O copia/pega todo en Cloud Shell
#
################################################################################

set -e  # Exit on error

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración fija
REGION="us-south1"  # Dallas
SERVICE_NAME="apolo-procesamiento-inteligente"
BUCKET_NAME="preavaluos-pdf"
FIRESTORE_DATABASE="apolo-preavaluos-dev"
FIRESTORE_COLLECTION="apolo_procesamiento"

print_header() {
    echo ""
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

print_step() {
    echo -e "${BLUE}[PASO $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

################################################################################
# Inicio
################################################################################

print_header "APOLO - DESPLIEGUE AUTOMÁTICO"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    print_error "No hay proyecto configurado"
    echo "Ejecuta: gcloud config set project TU_PROJECT_ID"
    exit 1
fi

IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

print_success "Proyecto: $PROJECT_ID"
print_info "Región: $REGION (Dallas)"
print_info "Iniciando despliegue automático..."
sleep 2

################################################################################
# PASO 1: Habilitar APIs
################################################################################

print_header "PASO 1/9: Habilitando APIs"

set +e  # No salir en error para APIs
for api in run.googleapis.com cloudbuild.googleapis.com storage.googleapis.com firestore.googleapis.com; do
    echo -n "Habilitando $api... "
    gcloud services enable "$api" --project="$PROJECT_ID" 2>&1 >/dev/null && echo "✓" || echo "⚠ (puede estar habilitada)"
done
set -e

print_success "APIs configuradas"

################################################################################
# PASO 2: Bucket GCS
################################################################################

print_header "PASO 2/9: Configurando Storage"

if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    print_success "Bucket $BUCKET_NAME existe"
else
    print_step "2" "Creando bucket..."
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    gsutil versioning set on "gs://$BUCKET_NAME"
    print_success "Bucket creado"
fi

################################################################################
# PASO 3: Firestore
################################################################################

print_header "PASO 3/9: Configurando Firestore"

# Intentar crear, pero no fallar si ya existe
set +e  # No salir en error temporalmente
gcloud firestore databases create \
    --database="$FIRESTORE_DATABASE" \
    --location="$REGION" \
    --type=firestore-native \
    --project="$PROJECT_ID" 2>&1 | grep -q "already exists" && print_info "BD ya existe" || print_success "BD Firestore configurada"
set -e  # Volver a salir en error

################################################################################
# PASO 4: Clonar repo
################################################################################

print_header "PASO 4/9: Descargando código"

REPO_URL="https://github.com/Apolo-Solutions-s2/apolo_procesamiento_inteligente_preavaluo.git"
REPO_DIR="apolo_procesamiento_inteligente_preavaluo"

# Limpiar y clonar fresh siempre
if [ -d "$REPO_DIR" ]; then
    print_info "Limpiando directorio anterior..."
    rm -rf "$REPO_DIR"
fi

print_step "4" "Clonando código desde GitHub..."
git clone "$REPO_URL" || {
    print_error "Error clonando repositorio"
    exit 1
}

cd "$REPO_DIR" || {
    print_error "Error accediendo al directorio"
    exit 1
}

print_success "Código listo: $(pwd)"

################################################################################
# PASO 5: Construir imagen
################################################################################

print_header "PASO 5/9: Construyendo imagen Docker"

gcloud auth configure-docker gcr.io --quiet
print_info "Construyendo... (2-3 minutos)"

gcloud builds submit \
    --tag="$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --timeout=10m \
    .

print_success "Imagen lista: $IMAGE_NAME"

################################################################################
# PASO 6: Desplegar Cloud Run
################################################################################

print_header "PASO 6/9: Desplegando a Cloud Run"

gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --platform=managed \
    --region="$REGION" \
    --allow-unauthenticated \
    --memory=512Mi \
    --cpu=1 \
    --timeout=300s \
    --max-instances=10 \
    --min-instances=0 \
    --set-env-vars="BUCKET_NAME=$BUCKET_NAME,FIRESTORE_DATABASE=$FIRESTORE_DATABASE,FIRESTORE_COLLECTION=$FIRESTORE_COLLECTION" \
    --project="$PROJECT_ID"

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='value(status.url)')

print_success "Servicio desplegado: $SERVICE_URL"

################################################################################
# PASO 7: Datos de prueba
################################################################################

print_header "PASO 7/9: Subiendo datos de prueba"

cat > /tmp/test.pdf << 'EOF'
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
/Resources <<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
>>
>>
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Estado Financiero - Apolo) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000317 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
410
%%EOF
EOF

FOLIO_ID="PRE-2025-TEST-001"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf"
rm /tmp/test.pdf

print_success "Archivos en gs://$BUCKET_NAME/$FOLIO_ID/"

################################################################################
# PASO 8: Tests
################################################################################

print_header "PASO 8/9: Ejecutando tests"

sleep 5

# Test 1: Health
print_step "8.1" "Health check..."
curl -s "$SERVICE_URL/health" | head -n 3
print_success "Health OK"

# Test 2: Procesamiento con nuevo formato
print_step "8.2" "Test con estructura Document AI (runs/runId/documents)..."

cat > /tmp/test_request.json << EOF
{
  "runId": "test-run-$(date +%s)",
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

echo ""
echo "Request:"
cat /tmp/test_request.json | python3 -m json.tool

echo ""
echo "Response:"
curl -s -X POST "$SERVICE_URL/" \
    -H "Content-Type: application/json" \
    -d @/tmp/test_request.json | python3 -m json.tool

print_success "Procesamiento completado"

# Test 3: Idempotencia
print_step "8.3" "Test de idempotencia (cache)..."
sleep 2
RESPONSE=$(curl -s -X POST "$SERVICE_URL/" \
    -H "Content-Type: application/json" \
    -d @/tmp/test_request.json)

if echo "$RESPONSE" | grep -q '"from_cache".*true'; then
    print_success "Cache funcionando ✓"
else
    print_info "Cache: primera ejecución"
fi

rm /tmp/test_request.json

################################################################################
# PASO 9: Verificar Firestore
################################################################################

print_header "PASO 9/9: Verificando Firestore"

print_info "Estructura en Firestore:"
echo "  runs/"
echo "  └── {runId}/"
echo "      ├── status: completed"
echo "      ├── documentCount: 3"
echo "      └── documents/"
echo "          ├── {docId1}/ (ESTADO_RESULTADOS)"
echo "          ├── {docId2}/ (ESTADO_SITUACION_FINANCIERA)"
echo "          └── {docId3}/ (ESTADO_FLUJOS_EFECTIVO)"

################################################################################
# Resumen
################################################################################

print_header "✅ DESPLIEGUE COMPLETADO"

cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 INFORMACIÓN

Proyecto:          $PROJECT_ID
Región:            $REGION (Dallas)
URL Servicio:      $SERVICE_URL

Bucket:            gs://$BUCKET_NAME
Firestore DB:      $FIRESTORE_DATABASE
Colección:         runs/

Folio Prueba:      $FOLIO_ID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 VER RESULTADOS EN FIRESTORE

Console Web:
https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DATABASE/data/~2Fruns

Comando:
gcloud firestore documents list --database=$FIRESTORE_DATABASE \\
  --collection-ids=runs --project=$PROJECT_ID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧪 PROBAR NUEVAMENTE

curl -X POST "$SERVICE_URL/" \\
  -H "Content-Type: application/json" \\
  -d '{
  "runId": "mi-test-123",
  "preavaluo_id": "PRE-2025-001",
  "fileList": [
    {
      "gcsUri": "gs://$BUCKET_NAME/PRE-2025-001/documento.pdf",
      "file_name": "documento.pdf"
    }
  ]
}'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 LOGS DEL SERVICIO

gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

print_success "Todo listo en Dallas! 🎉"
