# 🚀 Despliegue Manual en Cloud Shell - Paso a Paso

## ⚙️ PREPARACIÓN

```bash
# 1. Verificar proyecto activo
gcloud config get-value project

# 2. Si necesitas cambiar de proyecto:
# gcloud config set project TU_PROJECT_ID

# 3. Configurar variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-south1"
export SERVICE_NAME="apolo-procesamiento-inteligente"
export BUCKET_NAME="preavaluos-pdf"
export FIRESTORE_DATABASE="apolo-preavaluos-dev"
export FIRESTORE_COLLECTION="apolo_procesamiento"
export IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "✓ Proyecto: $PROJECT_ID"
echo "✓ Región: $REGION"
```

---

## 📦 PASO 1: HABILITAR APIs (1 min)

```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable firestore.googleapis.com

echo "✓ APIs habilitadas"
```

---

## 🪣 PASO 2: CREAR BUCKET (30 seg)

```bash
# Crear bucket
gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"

# Habilitar versionado
gsutil versioning set on "gs://$BUCKET_NAME"

echo "✓ Bucket creado: gs://$BUCKET_NAME"
```

---

## 🗄️ PASO 3: CREAR BASE DE DATOS FIRESTORE (30 seg)

```bash
gcloud firestore databases create \
    --database="$FIRESTORE_DATABASE" \
    --location="$REGION" \
    --type=firestore-native \
    --project="$PROJECT_ID"

echo "✓ Firestore DB: $FIRESTORE_DATABASE"
```

---

## 📥 PASO 4: CLONAR CÓDIGO (1 min)

```bash
# Clonar repositorio
git clone https://github.com/Apolo-Solutions-s2/apolo_procesamiento_inteligente_preavaluo.git

# Entrar al directorio
cd apolo_procesamiento_inteligente_preavaluo

# Verificar archivos principales
ls -la

echo "✓ Código descargado"
```

---

## 🐳 PASO 5: CONSTRUIR IMAGEN DOCKER (2-3 min)

```bash
# Configurar autenticación
gcloud auth configure-docker gcr.io --quiet

# Construir imagen
gcloud builds submit \
    --tag="$IMAGE_NAME" \
    --project="$PROJECT_ID" \
    --timeout=10m \
    .

echo "✓ Imagen construida: $IMAGE_NAME"
```

---

## ☁️ PASO 6: DESPLEGAR A CLOUD RUN (1 min)

```bash
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

# Obtener URL del servicio
export SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format='value(status.url)')

echo "✓ Servicio desplegado"
echo "✓ URL: $SERVICE_URL"
```

---

## 📄 PASO 7: SUBIR PDFs DE PRUEBA (30 seg)

```bash
# Crear PDF de prueba
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
(Estado Financiero - Prueba) Tj
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

# Subir archivos
export FOLIO_ID="PRE-2025-TEST-001"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/estado_resultados.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/balance_general.pdf"
gsutil cp /tmp/test.pdf "gs://$BUCKET_NAME/$FOLIO_ID/flujo_efectivo.pdf"

echo "✓ PDFs subidos a gs://$BUCKET_NAME/$FOLIO_ID/"
```

---

## 🧪 PASO 8: PROBAR EL SERVICIO

### Test 1: Health Check

```bash
curl "$SERVICE_URL/health"
```

**Respuesta esperada:**
```json
{
  "status": "ok",
  "firestore_db": "apolo-preavaluos-dev",
  "firestore_collection": "apolo_procesamiento",
  "bucket": "preavaluos-pdf"
}
```

---

### Test 2: Procesar Documentos (Estructura Document AI)

```bash
# Crear request
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

# Enviar request
curl -X POST "$SERVICE_URL/" \
    -H "Content-Type: application/json" \
    -d @/tmp/test_request.json | python3 -m json.tool
```

**Deberías ver:**
```json
{
  "runId": "test-run-XXXXX",
  "status": "completed",
  "results": [
    {
      "file_name": "estado_resultados.pdf",
      "status": "processed",
      "from_cache": false,
      "classification": {
        "documentType": "ESTADO_RESULTADOS",
        "confidence": 0.95
      },
      "extraction": {
        "fields": {
          "ORG_NAME": "...",
          "line_items": [...]
        }
      }
    },
    ...
  ]
}
```

---

### Test 3: Idempotencia (Cache)

```bash
# Reenviar la misma request (debe venir de cache)
curl -X POST "$SERVICE_URL/" \
    -H "Content-Type: application/json" \
    -d @/tmp/test_request.json | python3 -m json.tool

# Busca: "from_cache": true
```

---

## 🔍 PASO 9: VERIFICAR FIRESTORE

### Opción A: Desde Comando

```bash
# Listar runs
gcloud firestore documents list \
    --database="$FIRESTORE_DATABASE" \
    --collection-ids=runs \
    --project="$PROJECT_ID"

# Ver un run específico (reemplaza {runId} con el ID real)
gcloud firestore documents get "runs/{runId}" \
    --database="$FIRESTORE_DATABASE" \
    --project="$PROJECT_ID"

# Listar documentos procesados de un run
gcloud firestore documents list \
    --database="$FIRESTORE_DATABASE" \
    --collection-ids=documents \
    --project="$PROJECT_ID"
```

### Opción B: Desde Console Web

Abre en tu navegador:
```bash
echo "https://console.firebase.google.com/project/$PROJECT_ID/firestore/databases/$FIRESTORE_DATABASE/data/~2Fruns"
```

**Deberías ver:**
```
runs/
└── test-run-XXXXX/
    ├── runId: "test-run-XXXXX"
    ├── status: "completed"
    ├── documentCount: 3
    ├── processedCount: 3
    └── documents/
        ├── {docId1}/
        │   ├── classification.documentType: "ESTADO_RESULTADOS"
        │   └── extraction.fields.line_items: [...]
        ├── {docId2}/
        │   ├── classification.documentType: "ESTADO_SITUACION_FINANCIERA"
        │   └── extraction.fields.line_items: [...]
        └── {docId3}/
            ├── classification.documentType: "ESTADO_FLUJOS_EFECTIVO"
            └── extraction.fields.line_items: [...]
```

---

## 📊 COMANDOS ÚTILES

### Ver logs en tiempo real
```bash
gcloud run services logs read "$SERVICE_NAME" \
    --region="$REGION" \
    --limit=50 \
    --project="$PROJECT_ID"
```

### Ver información del servicio
```bash
gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"
```

### Ver métricas
```bash
gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(status.traffic)"
```

### Actualizar variables de entorno
```bash
gcloud run services update "$SERVICE_NAME" \
    --region="$REGION" \
    --set-env-vars="NUEVA_VAR=valor" \
    --project="$PROJECT_ID"
```

---

## 🔄 REDESPLIEGUE (después de cambios en código)

```bash
# 1. Hacer cambios en el código local

# 2. Reconstruir imagen
gcloud builds submit --tag="$IMAGE_NAME" .

# 3. Redesplegar
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"
```

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### Error: "Project not found"
```bash
gcloud config set project TU_PROJECT_ID
gcloud config get-value project
```

### Error: "Firestore database already exists"
```bash
# Es normal si ya existía, continúa con el siguiente paso
gcloud firestore databases list --project="$PROJECT_ID"
```

### Error: "Permission denied"
```bash
# Verifica permisos de la cuenta de servicio
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" \
    --role="roles/datastore.user"
```

### Ver errores en Cloud Run
```bash
gcloud run services logs read "$SERVICE_NAME" \
    --region="$REGION" \
    --limit=100 \
    --project="$PROJECT_ID"
```

---

## ✅ CHECKLIST POST-DESPLIEGUE

- [ ] APIs habilitadas
- [ ] Bucket `preavaluos-pdf` creado
- [ ] Firestore DB `apolo-preavaluos-dev` creada
- [ ] Código clonado
- [ ] Imagen Docker construida
- [ ] Cloud Run desplegado
- [ ] PDFs de prueba subidos
- [ ] Health check responde OK
- [ ] Procesamiento funciona (3 documentos)
- [ ] Cache/idempotencia funciona
- [ ] Datos visibles en Firestore

---

## 📚 DOCUMENTACIÓN

- **Esquema Firestore**: `docs/FIRESTORE_SCHEMA.md`
- **Guía completa**: `COMO_DESPLEGAR.md`
- **Resumen cambios**: `FIRESTORE_UPDATE_SUMMARY.md`

---

**¡Todo listo para producción en Dallas! 🚀**
