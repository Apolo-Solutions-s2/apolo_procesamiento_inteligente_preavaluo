# Guía Rápida de Pruebas

## 📌 Flujo de Prueba Automático del Servicio

El microservicio se prueba automáticamente durante el despliegue. El script `./test_uuid_processing.sh` en la carpeta `Cloud Shell/`:

1. ✅ Crea una carpeta con UUID único
2. ✅ Sube 2 PDFs de prueba
3. ✅ Sube un archivo `is_ready` (minúsculas)
4. ✅ Verifica que el microservicio procese los 2 PDFs
5. ✅ Valida la estructura de carpetas y logs
6. ✅ Limpia los recursos (opcional con `--cleanup`)

**Nota**: Con el cambio a `update_code.sh`, estos tests se saltan por defecto durante actualizaciones de código. Puedes ejecutarlos manualmente con:
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./test_uuid_processing.sh
```

---

## 🧪 Pruebas Manuales - Flujo Básico

### 1. Sube archivos PDF a una carpeta
```bash
# En Cloud Shell, sube PDFs a una carpeta
gsutil cp documento1.pdf gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
gsutil cp documento2.pdf gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
gsutil cp documento3.pdf gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
```

### 2. Sube el archivo IS_READY para activar el trigger
```bash
# Crear archivo vacío (sin extensión)
echo -n "" > IS_READY

# Subir a la misma carpeta
gsutil cp IS_READY gs://apolo-preavaluos-pdf-dev/MI-CARPETA/
```

### 3. Verifica los logs del microservicio
```bash
# Ver logs en tiempo real
gcloud run services logs read apolo-procesamiento-inteligente \
  --region=us-south1 \
  --limit=50 \
  --follow

# Buscar eventos de tu carpeta
gcloud logging read "resource.type=cloud_run_revision AND textPayload:MI-CARPETA" \
  --limit=100 \
  --format="table(timestamp,textPayload)"
```

### 4. Verifica los resultados en Firestore
```bash
# La estructura será:
# folios/{folio_id}/documentos/{doc_id}/extracciones/{extraction_id}

# Donde:
# - folio_id = hash(bucket:MI-CARPETA) 
# - doc_id = hash(folio_id:nombre_archivo:generation)
```

---

## 🧪 Pruebas Locales (Sin Desplegar)

### 1. Ejecutar localmente con Docker
```powershell
# Construir imagen
.\build-docker.ps1

# Ejecutar (necesitas credentials.json)
docker run -p 8080:8080 --rm `
  -e GCP_PROJECT_ID=tu-proyecto-id `
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json `
  -v ${PWD}/credentials.json:/app/credentials.json:ro `
  apolo-procesamiento-inteligente:local-latest

# En otra terminal, probar
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode individual
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode batch
```

### 2. Ejecutar localmente con functions-framework (sin Docker)
```powershell
# Activar entorno virtual
.\venv\Scripts\activate  # o: source venv/bin/activate en Linux

# Configurar credenciales
$env:GOOGLE_APPLICATION_CREDENTIALS = "path/to/credentials.json"
$env:GCP_PROJECT_ID = "tu-proyecto-id"

# Ejecutar
functions-framework --target=process_folder_on_ready --debug --port=8080

# En otra terminal, simular evento Eventarc (JSON en POST)
# El servicio espera formato CloudEvent de Eventarc
```

### 1. Ejecutar localmente con Docker
```powershell
# Construir imagen
.\build-docker.ps1

# Ejecutar (necesitas credentials.json)
docker run -p 8080:8080 --rm `
  -e BUCKET_NAME=preavaluos-pdf `
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json `
  -v ${PWD}/credentials.json:/app/credentials.json:ro `
  apolo-procesamiento-inteligente:local-latest

# En otra terminal, probar
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode individual
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode batch
```

### 2. Ejecutar localmente con functions-framework (sin Docker)
```powershell
# Activar entorno virtual
.\venv\Scripts\activate  # o: source venv/bin/activate en Linux

# Configurar credenciales
$env:GOOGLE_APPLICATION_CREDENTIALS = "path/to/credentials.json"
$env:BUCKET_NAME = "preavaluos-pdf"

# Ejecutar
functions-framework --target=document_processor --debug --port=8080

# En otra terminal, probar
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode individual
```

## 🌐 Pruebas en Cloud Run (Desplegado)

### 1. Desplegar a Cloud Run
```powershell
# Configurar proyecto
$env:GCP_PROJECT_ID = "tu-proyecto-id"

# Desplegar
.\deploy-cloudrun.ps1 -Environment dev -ProjectId "tu-proyecto-id"

# Obtendrás una URL como:
# https://apolo-procesamiento-inteligente-abc123-uc.a.run.app
```

### 2. Probar el servicio desplegado
```powershell
# Guardar la URL del servicio
$SERVICE_URL = "https://apolo-procesamiento-inteligente-abc123-uc.a.run.app"

# Prueba individual
.\test-cloudrun.ps1 -ServiceUrl $SERVICE_URL -Mode individual

# Prueba batch
.\test-cloudrun.ps1 -ServiceUrl $SERVICE_URL -Mode batch
```

## 🔍 Validaciones que Hace el Script de Prueba

✅ **Health Check**: Verifica que el servicio responde
✅ **Procesamiento Individual**: Procesa un PDF específico por su URI
✅ **Procesamiento Batch**: Procesa múltiples PDFs de una carpeta
✅ **Manejo de Errores**: Valida respuestas de error
✅ **Validación de Response**: Verifica estructura y datos de respuesta

## 📊 Qué Validar Manualmente

### Conectividad con GCS
- Verifica que el bucket existe: `gsutil ls gs://preavaluos-pdf/`
- Sube archivos de prueba: `gsutil cp test.pdf gs://preavaluos-pdf/PRE-2025-001/`

### Conectividad con Firestore
- Crea la base de datos en GCP Console
- Verifica permisos del service account
- Revisa colección `apolo_procesamiento` después de procesar

### Logs en Cloud Run
```powershell
# Ver logs en tiempo real
gcloud run services logs read apolo-procesamiento-inteligente `
  --region us-south1 `
  --limit 50 `
  --format json
```

## 🎯 Casos de Prueba Recomendados

### Test 1: Archivo válido individual
```json
{
  "folioId": "PRE-2025-001",
  "fileId": "balance.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-001/balance.pdf"
}
```
Esperado: Status 200, documento procesado

### Test 2: Carpeta con múltiples archivos
```json
{
  "folder_prefix": "PRE-2025-001/",
  "preavaluo_id": "PRE-2025-001"
}
```
Esperado: Status 200, múltiples documentos procesados

### Test 3: Archivo no existente
```json
{
  "folioId": "PRE-2025-999",
  "fileId": "noexiste.pdf",
  "gcs_pdf_uri": "gs://preavaluos-pdf/PRE-2025-999/noexiste.pdf"
}
```
Esperado: Status 200 con no_files o error específico

### Test 4: Request sin parámetros
```json
{}
```
Esperado: Status 500 con error de validación

### Test 5: PDF corrupto
Sube un archivo .txt renombrado como .pdf
Esperado: Status 500 con error INVALID_PDF_FORMAT

## 🔧 Troubleshooting

### Error: "Stub file not found for google.cloud"
- Ya está configurado en pyrightconfig.json
- Es solo un warning del IDE, no afecta ejecución

### Error: "Permission denied" en GCS
```powershell
# Verificar service account
gcloud projects get-iam-policy tu-proyecto-id

# Agregar permisos
gcloud projects add-iam-policy-binding tu-proyecto-id `
  --member="serviceAccount:apolo-procesamiento-sa@tu-proyecto-id.iam.gserviceaccount.com" `
  --role="roles/storage.objectViewer"
```

### Error: "Connection timeout" en Cloud Run
- Verifica que el timeout está en 300s (5 min)
- Revisa que max-instances > 0
- Verifica la región del servicio

## 📝 Checklist de Validación Completa

Antes de pasar a producción, verifica:

- [ ] Servicio responde a health check
- [ ] Procesa archivos individuales correctamente
- [ ] Procesa carpetas con múltiples archivos
- [ ] Maneja errores sin crashear
- [ ] Valida PDFs por magic bytes
- [ ] Se conecta exitosamente a GCS
- [ ] Persiste resultados en Firestore (si está configurado)
- [ ] Logs estructurados visibles en Cloud Logging
- [ ] Respuestas tienen estructura correcta (status, run_id, results)
- [ ] Tiempos de respuesta aceptables (< 30s para batch pequeño)
- [ ] Escalado funciona (probar con múltiples requests concurrentes)

## 🚀 Próximos Pasos (Con Cloud Workflows)

Cuando implementes Cloud Workflows:

1. Despliega el workflow: `gcloud workflows deploy apolo-workflow --source=workflow.yaml`
2. Actualiza `processor_url` en workflow.yaml con tu URL de Cloud Run
3. Prueba el workflow: `gcloud workflows execute apolo-workflow --data='{"folder_prefix":"PRE-2025-001/"}'`
4. El workflow manejará automáticamente la autenticación OIDC
