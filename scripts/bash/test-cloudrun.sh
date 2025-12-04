#!/bin/bash
# Script de prueba para el microservicio en Cloud Run
# Uso: ./test-cloudrun.sh [SERVICE_URL] [MODE]
# Ejemplo: ./test-cloudrun.sh "https://tu-servicio.run.app" individual

set -e

SERVICE_URL="${1:-http://localhost:8080}"
MODE="${2:-individual}"

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

function test_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

function test_step() {
    echo -e "${YELLOW}➤ $1${NC}"
}

function test_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function test_error() {
    echo -e "${RED}✗ $1${NC}"
}

# =========================================
# TEST 1: Health Check
# =========================================
test_header "TEST 1: Health Check"
test_step "Probando conectividad con $SERVICE_URL..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $SERVICE_URL -X GET || echo "000")

if [ "$HTTP_STATUS" == "405" ] || [ "$HTTP_STATUS" == "200" ]; then
    test_success "Servicio respondiendo (HTTP $HTTP_STATUS)"
else
    test_error "Servicio no disponible (HTTP $HTTP_STATUS)"
    exit 1
fi

# =========================================
# TEST 2: Procesamiento Individual
# =========================================
if [ "$MODE" == "individual" ]; then
    test_header "TEST 2: Procesamiento Individual"
    test_step "Procesando un documento específico..."
    
    BODY=$(cat <<EOF
{
  "folioId": "PRE-2025-001",
  "fileId": "balance_general.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance_general.pdf",
  "workflow_execution_id": "test-$(date +%Y%m%d%H%M%S)"
}
EOF
)

    echo -e "${GRAY}Request Body:${NC}"
    echo -e "${GRAY}$BODY${NC}"
    echo ""

    RESPONSE=$(curl -s -X POST $SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "$BODY")

    test_success "Procesamiento completado"
    echo ""
    echo -e "${GRAY}Response:${NC}"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    
    STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" == "processed" ] || [ "$STATUS" == "no_files" ]; then
        test_success "Status: $STATUS"
    elif [ "$STATUS" == "error" ]; then
        test_error "Error en procesamiento"
    fi
fi

# =========================================
# TEST 3: Procesamiento Batch
# =========================================
if [ "$MODE" == "batch" ]; then
    test_header "TEST 3: Procesamiento Batch (Folder)"
    test_step "Procesando todos los PDFs en una carpeta..."
    
    BODY=$(cat <<EOF
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001",
  "extensions": [".pdf"],
  "max_items": 10,
  "workflow_execution_id": "test-batch-$(date +%Y%m%d%H%M%S)"
}
EOF
)

    echo -e "${GRAY}Request Body:${NC}"
    echo -e "${GRAY}$BODY${NC}"
    echo ""

    RESPONSE=$(curl -s -X POST $SERVICE_URL \
        -H "Content-Type: application/json" \
        -d "$BODY")

    test_success "Procesamiento completado"
    echo ""
    echo -e "${GRAY}Response:${NC}"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    
    STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")
    DOC_COUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('document_count', 0))" 2>/dev/null || echo "0")
    
    if [ "$STATUS" == "processed" ] || [ "$STATUS" == "no_files" ]; then
        test_success "Status: $STATUS"
        test_success "Documentos procesados: $DOC_COUNT"
    elif [ "$STATUS" == "error" ]; then
        test_error "Error en procesamiento"
    fi
fi

# =========================================
# TEST 4: Manejo de Errores
# =========================================
test_header "TEST 4: Validación de Errores"
test_step "Probando manejo de request inválido..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST $SERVICE_URL \
    -H "Content-Type: application/json" \
    -d '{"invalid_param": "test"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" == "500" ]; then
    test_success "Manejo de errores funcionando (HTTP 500)"
    echo -e "${YELLOW}Error esperado: $(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('error', {}).get('message', 'N/A'))" 2>/dev/null || echo "N/A")${NC}"
else
    test_error "Error inesperado: HTTP $HTTP_CODE"
fi

# =========================================
# RESUMEN
# =========================================
echo ""
test_header "Tests Completados"
echo -e "Servicio: $SERVICE_URL"
echo -e "Modo: $MODE"
echo ""
echo -e "${BLUE}Para más pruebas:${NC}"
echo -e "${GRAY}  Individual: ./test-cloudrun.sh '$SERVICE_URL' individual${NC}"
echo -e "${GRAY}  Batch:      ./test-cloudrun.sh '$SERVICE_URL' batch${NC}"
echo ""
