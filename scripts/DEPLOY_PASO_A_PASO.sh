# ═══════════════════════════════════════════════════════════════════════════
# APOLO - DESPLIEGUE COMANDO POR COMANDO (Cloud Shell)
# ═══════════════════════════════════════════════════════════════════════════
# 
# INSTRUCCIONES: Copia y pega CADA BLOQUE uno por uno
#                Espera a que termine antes de copiar el siguiente
#
# ═══════════════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 0: CONFIGURACIÓN INICIAL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-south1"
export SERVICE_NAME="apolo-procesamiento-inteligente"
export BUCKET_NAME="preavaluos-pdf"
export FIRESTORE_DB="apolo-preavaluos-dev"
export IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CONFIGURACIÓN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Proyecto: $PROJECT_ID"
echo "Región:   $REGION"
echo "Servicio: $SERVICE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 1: HABILITAR APIs (copia desde aquí hasta la línea de abajo)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [1/9] Habilitando APIs..."
gcloud services enable run.googleapis.com --project="$PROJECT_ID" && echo "✓ Cloud Run"
gcloud services enable cloudbuild.googleapis.com --project="$PROJECT_ID" && echo "✓ Cloud Build"
gcloud services enable storage.googleapis.com --project="$PROJECT_ID" && echo "✓ Storage"
gcloud services enable firestore.googleapis.com --project="$PROJECT_ID" && echo "✓ Firestore"
echo "✓ APIs habilitadas"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 2: CREAR BUCKET
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [2/9] Configurando Storage..."
gsutil ls -b "gs://$BUCKET_NAME" 2>/dev/null || gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
gsutil versioning set on "gs://$BUCKET_NAME" 2>/dev/null
echo "✓ Bucket configurado: gs://$BUCKET_NAME"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 3: CREAR FIRESTORE DATABASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [3/9] Configurando Firestore..."
gcloud firestore databases create --database="$FIRESTORE_DB" --location="$REGION" --type=firestore-native --project="$PROJECT_ID" 2>/dev/null
echo "✓ Firestore configurado"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 4: CLONAR CÓDIGO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [4/9] Descargando código..."
cd ~
rm -rf apolo_procesamiento_inteligente_preavaluo 2>/dev/null
git clone https://github.com/Apolo-Solutions-s2/apolo_procesamiento_inteligente_preavaluo.git
cd apolo_procesamiento_inteligente_preavaluo
echo "✓ Código descargado: $(pwd)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 5: CONSTRUIR IMAGEN DOCKER (2-3 minutos - SE PACIENTE)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [5/9] Construyendo imagen (2-3 min)..."
gcloud auth configure-docker gcr.io --quiet
gcloud builds submit --tag="$IMAGE_NAME" --timeout=10m .
echo "✓ Imagen construida"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 6: DESPLEGAR A CLOUD RUN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [6/9] Desplegando a Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image="$IMAGE_NAME" \
  --platform=managed \
  --region="$REGION" \
  --allow-unauthenticated \
  --memory=512Mi \
  --timeout=300s \
  --max-instances=10 \
  --set-env-vars="BUCKET_NAME=$BUCKET_NAME,FIRESTORE_DATABASE=$FIRESTORE_DB,FIRESTORE_COLLECTION=apolo_procesamiento" \
  --project="$PROJECT_ID"

export SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --format='value(status.url)')
echo "✓ Servicio desplegado: $SERVICE_URL"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 7: SUBIR PDFs DE PRUEBA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [7/9] Subiendo archivos de prueba..."

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

export FOLIO_ID="PRE-2025-TEST-001"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf"
echo "✓ Archivos subidos"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 8: PROBAR SERVICIO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━ [8/9] Probando servicio..."
sleep 5

# Health check
curl -s "$SERVICE_URL/health" | head -n 3
echo ""

# Procesamiento
cat > /tmp/request.json << EOF
{
  "runId": "test-$(date +%s)",
  "preavaluo_id": "$FOLIO_ID",
  "fileList": [
    {"gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf", "file_name": "estado_resultados.pdf"},
    {"gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf", "file_name": "balance_general.pdf"},
    {"gcsUri": "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf", "file_name": "flujo_efectivo.pdf"}
  ]
}
EOF

echo "Procesando documentos..."
curl -s -X POST "$SERVICE_URL/" -H "Content-Type: application/json" -d @/tmp/request.json | python3 -m json.tool
echo "✓ Test completado"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BLOQUE 9: VER RESUMEN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ DESPLIEGUE COMPLETADO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Proyecto:      $PROJECT_ID"
echo "Región:        $REGION (Dallas)"
echo "Servicio:      $SERVICE_URL"
echo ""
echo "Bucket:        gs://$BUCKET_NAME"
echo "Firestore DB:  $FIRESTORE_DB"
echo ""
echo "🔍 Ver Firestore:"
echo "https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DB/data/~2Fruns"
echo ""
echo "📊 Ver logs:"
echo "gcloud run services logs read $SERVICE_NAME --region=$REGION --limit=50"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
