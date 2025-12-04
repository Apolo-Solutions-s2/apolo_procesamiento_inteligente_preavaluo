#!/bin/bash
################################################################################
# Apolo - Despliegue Completo para Cloud Shell
# 
# Script autocontenido para copiar/pegar en Google Cloud Shell
# Despliega el microservicio de procesamiento inteligente en Dallas (us-south1)
# 
# Uso:
#   1. Abre Cloud Shell en GCP Console
#   2. Copia y pega TODO este script
#   3. Presiona Enter
#   4. Sigue las instrucciones interactivas
#
################################################################################

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración fija
REGION="us-south1"  # Dallas
SERVICE_NAME="apolo-procesamiento-inteligente"
BUCKET_NAME="preavaluos-pdf"
FIRESTORE_DATABASE="apolo-preavaluos-dev"
FIRESTORE_COLLECTION="apolo_procesamiento"
IMAGE_NAME="gcr.io/\${PROJECT_ID}/${SERVICE_NAME}"

################################################################################
# Funciones auxiliares
################################################################################

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

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

################################################################################
# Validaciones iniciales
################################################################################

print_header "APOLO - DESPLIEGUE EN CLOUD SHELL"

# Verificar que estamos en Cloud Shell
if [ -z "$CLOUD_SHELL" ]; then
    print_warning "No estás en Cloud Shell, pero continuaremos..."
fi

# Obtener PROJECT_ID actual
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    print_error "No hay proyecto configurado"
    echo ""
    echo "Configura tu proyecto con:"
    echo "  gcloud config set project TU_PROJECT_ID"
    exit 1
fi

print_success "Proyecto detectado: $PROJECT_ID"
print_info "Región: $REGION (Dallas)"
print_info "Base de datos Firestore: $FIRESTORE_DATABASE"
print_info "Colección: $FIRESTORE_COLLECTION"

echo ""
read -p "¿Continuar con este proyecto? (s/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    print_warning "Despliegue cancelado"
    exit 0
fi

################################################################################
# PASO 1: Habilitar APIs necesarias
################################################################################

print_header "PASO 1: Habilitando APIs de GCP"

APIS=(
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "storage.googleapis.com"
    "firestore.googleapis.com"
    "artifactregistry.googleapis.com"
)

for api in "${APIS[@]}"; do
    print_step "1" "Habilitando $api..."
    if gcloud services enable "$api" --project="$PROJECT_ID" 2>/dev/null; then
        print_success "$api habilitada"
    else
        print_warning "$api ya estaba habilitada o hubo un error (continuando...)"
    fi
done

################################################################################
# PASO 2: Crear bucket de GCS (si no existe)
################################################################################

print_header "PASO 2: Configurando Google Cloud Storage"

print_step "2" "Verificando bucket $BUCKET_NAME..."

if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    print_success "Bucket $BUCKET_NAME ya existe"
else
    print_step "2" "Creando bucket $BUCKET_NAME en $REGION..."
    if gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"; then
        print_success "Bucket creado exitosamente"
        
        # Configurar versionado
        gsutil versioning set on "gs://$BUCKET_NAME"
        print_success "Versionado habilitado"
        
        # Configurar lifecycle (opcional - eliminar objetos después de 90 días)
        echo '{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}' > /tmp/lifecycle.json
        gsutil lifecycle set /tmp/lifecycle.json "gs://$BUCKET_NAME"
        print_success "Política de lifecycle configurada (90 días)"
        rm /tmp/lifecycle.json
    else
        print_error "Error creando bucket"
        exit 1
    fi
fi

################################################################################
# PASO 3: Configurar Firestore
################################################################################

print_header "PASO 3: Configurando Firestore"

print_step "3" "Verificando base de datos Firestore..."

# Intentar crear la base de datos (si ya existe, fallará silenciosamente)
if gcloud firestore databases create \
    --database="$FIRESTORE_DATABASE" \
    --location="$REGION" \
    --type=firestore-native \
    --project="$PROJECT_ID" 2>/dev/null; then
    print_success "Base de datos $FIRESTORE_DATABASE creada"
else
    print_info "Base de datos $FIRESTORE_DATABASE ya existe o no se pudo crear"
    print_info "Verifica manualmente en: https://console.firebase.google.com/project/$PROJECT_ID/firestore"
fi

print_info "Colección '$FIRESTORE_COLLECTION' se creará automáticamente al procesar el primer documento"

################################################################################
# PASO 4: Clonar repositorio
################################################################################

print_header "PASO 4: Descargando código fuente"

REPO_URL="https://github.com/Apolo-Solutions-s2/apolo_procesamiento_inteligente_preavaluo.git"
REPO_DIR="apolo_procesamiento_inteligente_preavaluo"

if [ -d "$REPO_DIR" ]; then
    print_warning "El directorio $REPO_DIR ya existe"
    read -p "¿Eliminar y clonar nuevamente? (s/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        rm -rf "$REPO_DIR"
        print_step "4" "Clonando repositorio..."
        git clone "$REPO_URL"
        print_success "Repositorio clonado"
    else
        print_info "Usando directorio existente"
    fi
else
    print_step "4" "Clonando repositorio desde GitHub..."
    git clone "$REPO_URL"
    print_success "Repositorio clonado"
fi

cd "$REPO_DIR"
print_success "Directorio de trabajo: $(pwd)"

################################################################################
# PASO 5: Construir y subir imagen Docker
################################################################################

print_header "PASO 5: Construyendo imagen Docker"

print_step "5" "Configurando autenticación para Container Registry..."
gcloud auth configure-docker gcr.io --quiet

print_step "5" "Construyendo imagen con Cloud Build..."
print_info "Esto puede tomar 2-3 minutos..."

if gcloud builds submit \
    --tag="$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --timeout=10m \
    .; then
    print_success "Imagen construida y subida: $IMAGE_NAME"
else
    print_error "Error construyendo imagen"
    exit 1
fi

################################################################################
# PASO 6: Desplegar a Cloud Run
################################################################################

print_header "PASO 6: Desplegando a Cloud Run"

print_step "6" "Desplegando servicio en $REGION..."

if gcloud run deploy "$SERVICE_NAME" \
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
    --project="$PROJECT_ID"; then
    print_success "Servicio desplegado exitosamente"
else
    print_error "Error desplegando servicio"
    exit 1
fi

# Obtener URL del servicio
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='value(status.url)')

print_success "URL del servicio: $SERVICE_URL"

################################################################################
# PASO 7: Crear datos de prueba en GCS
################################################################################

print_header "PASO 7: Preparando datos de prueba"

print_step "7" "Creando estructura de carpetas en GCS..."

# Crear un PDF de prueba simple
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
(Documento de Prueba - Apolo) Tj
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

# Subir archivos de prueba
FOLIO_ID="PRE-2025-TEST-001"

print_step "7" "Subiendo documentos de prueba..."
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/registros_patronales.pdf"

print_success "Archivos de prueba subidos a gs://$BUCKET_NAME/$FOLIO_ID/"

# Limpiar
rm /tmp/test.pdf

################################################################################
# PASO 8: Ejecutar pruebas
################################################################################

print_header "PASO 8: Ejecutando pruebas"

# Esperar un poco para que el servicio esté completamente listo
print_info "Esperando 10 segundos para que el servicio esté listo..."
sleep 10

# Test 1: Health Check
print_step "8.1" "Test: Health Check"
if curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" | grep -q "200\|405"; then
    print_success "Health check OK"
else
    print_error "Health check falló"
fi

# Test 2: Procesamiento individual
print_step "8.2" "Test: Procesamiento Individual"
echo ""
echo -e "${YELLOW}Request:${NC}"
cat << EOF | tee /tmp/request_individual.json
{
  "folioId": "$FOLIO_ID",
  "fileId": "balance_general.pdf",
  "gcs_pdf_uri": "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf",
  "workflow_execution_id": "test-$(date +%s)"
}
EOF

echo ""
echo -e "${YELLOW}Response:${NC}"
RESPONSE=$(curl -s -X POST "$SERVICE_URL" \
    -H "Content-Type: application/json" \
    -d @/tmp/request_individual.json)

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status".*"processed"'; then
    print_success "Procesamiento individual OK"
else
    print_warning "Revisar respuesta del procesamiento individual"
fi

# Test 3: Procesamiento batch
print_step "8.3" "Test: Procesamiento Batch (carpeta completa)"
echo ""
echo -e "${YELLOW}Request:${NC}"
cat << EOF | tee /tmp/request_batch.json
{
  "folder_prefix": "$FOLIO_ID/",
  "preavaluo_id": "$FOLIO_ID",
  "extensions": [".pdf"],
  "max_items": 500,
  "workflow_execution_id": "test-batch-$(date +%s)"
}
EOF

echo ""
echo -e "${YELLOW}Response:${NC}"
RESPONSE_BATCH=$(curl -s -X POST "$SERVICE_URL" \
    -H "Content-Type: application/json" \
    -d @/tmp/request_batch.json)

echo "$RESPONSE_BATCH" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BATCH"

if echo "$RESPONSE_BATCH" | grep -q '"document_count".*[1-9]'; then
    print_success "Procesamiento batch OK - Documentos procesados"
else
    print_warning "Revisar respuesta del procesamiento batch"
fi

# Test 4: Idempotencia (reenviar misma request)
print_step "8.4" "Test: Idempotencia (cache hit)"
echo ""
echo -e "${YELLOW}Re-enviando request individual (debería usar cache)...${NC}"
RESPONSE_CACHE=$(curl -s -X POST "$SERVICE_URL" \
    -H "Content-Type: application/json" \
    -d @/tmp/request_individual.json)

if echo "$RESPONSE_CACHE" | grep -q '"from_cache".*true'; then
    print_success "Idempotencia OK - Resultado desde cache"
else
    print_info "Cache no detectado (puede ser normal en primera ejecución)"
fi

# Test 5: Manejo de errores
print_step "8.5" "Test: Manejo de errores (archivo inexistente)"
echo ""
RESPONSE_ERROR=$(curl -s -X POST "$SERVICE_URL" \
    -H "Content-Type: application/json" \
    -d '{
  "folioId": "INEXISTENTE",
  "fileId": "noexiste.pdf",
  "gcs_pdf_uri": "gs://'"$BUCKET_NAME"'/INEXISTENTE/noexiste.pdf",
  "workflow_execution_id": "test-error"
}')

if echo "$RESPONSE_ERROR" | grep -q '"status".*"error"'; then
    print_success "Manejo de errores OK"
else
    print_warning "Revisar manejo de errores"
fi

# Limpiar archivos temporales
rm -f /tmp/request_individual.json /tmp/request_batch.json

################################################################################
# PASO 9: Verificar Firestore
################################################################################

print_header "PASO 9: Verificando Firestore"

print_step "9" "Consultando documentos en Firestore..."

# Intentar listar documentos (requiere firestore API)
print_info "Para ver los documentos procesados en Firestore:"
echo ""
echo "  gcloud firestore documents list \\"
echo "    --database=$FIRESTORE_DATABASE \\"
echo "    --collection-ids=$FIRESTORE_COLLECTION \\"
echo "    --project=$PROJECT_ID"
echo ""
echo "O visita:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DATABASE/data/~2F$FIRESTORE_COLLECTION"

################################################################################
# Resumen final
################################################################################

print_header "RESUMEN DE DESPLIEGUE"

echo ""
print_success "¡Despliegue completado exitosamente!"
echo ""

cat << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 INFORMACIÓN DEL DESPLIEGUE

Proyecto GCP:          $PROJECT_ID
Región:                $REGION (Dallas)
Servicio Cloud Run:    $SERVICE_NAME
URL del Servicio:      $SERVICE_URL

Bucket GCS:            gs://$BUCKET_NAME
Base de datos:         $FIRESTORE_DATABASE
Colección Firestore:   $FIRESTORE_COLLECTION

Folio de Prueba:       $FOLIO_ID
Archivos de Prueba:    gs://$BUCKET_NAME/$FOLIO_ID/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 COMANDOS ÚTILES

# Ver logs del servicio
gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50

# Ver información del servicio
gcloud run services describe $SERVICE_NAME --region=$REGION

# Actualizar variables de entorno
gcloud run services update $SERVICE_NAME \\
  --region=$REGION \\
  --set-env-vars="NUEVA_VAR=valor"

# Redesplegar (después de cambios en código)
gcloud builds submit --tag=$IMAGE_NAME .
gcloud run deploy $SERVICE_NAME --image=$IMAGE_NAME --region=$REGION

# Ver documentos en Firestore
gcloud firestore documents list \\
  --database=$FIRESTORE_DATABASE \\
  --collection-ids=$FIRESTORE_COLLECTION

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧪 PROBAR EL SERVICIO

# Procesamiento individual
curl -X POST "$SERVICE_URL" \\
  -H "Content-Type: application/json" \\
  -d '{
  "folioId": "TU_FOLIO",
  "fileId": "documento.pdf",
  "gcs_pdf_uri": "gs://$BUCKET_NAME/TU_FOLIO/documento.pdf",
  "workflow_execution_id": "test-123"
}'

# Procesamiento batch (carpeta completa)
curl -X POST "$SERVICE_URL" \\
  -H "Content-Type: application/json" \\
  -d '{
  "folder_prefix": "TU_FOLIO/",
  "preavaluo_id": "TU_FOLIO",
  "extensions": [".pdf"],
  "max_items": 500,
  "workflow_execution_id": "test-batch-123"
}'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 CONSOLAS WEB

Cloud Run:
  https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME?project=$PROJECT_ID

Cloud Storage:
  https://console.cloud.google.com/storage/browser/$BUCKET_NAME?project=$PROJECT_ID

Firestore:
  https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DATABASE

Logs:
  https://console.cloud.google.com/logs/query?project=$PROJECT_ID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

print_success "Todos los recursos están listos en la región de Dallas (us-south1)"
print_info "Base de datos Firestore: $FIRESTORE_DATABASE"
print_info "Los documentos procesados se guardarán en la colección: $FIRESTORE_COLLECTION"

echo ""
print_header "FIN DEL DESPLIEGUE"
