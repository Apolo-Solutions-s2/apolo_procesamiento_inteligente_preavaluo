# 🚀 Guía de Inicio Rápido - Apolo Document Processing

## 📌 Activación por Archivo IS_READY

El microservicio **apolo-procesamiento-inteligente** se activa automáticamente cuando se sube un archivo llamado **IS_READY** (sin extensión) a cualquier carpeta del bucket `apolo-preavaluos-pdf-dev`.

### Proceso Automático:
1. Subes archivos PDF a una carpeta (ej. `CARPETA-UUID/documento1.pdf`)
2. Subes un archivo vacío llamado `IS_READY` a la misma carpeta (sin extensión)
3. Eventarc detecta el archivo y activa el trigger automáticamente
4. El microservicio procesa **TODOS los archivos PDF** de esa carpeta en paralelo
5. El archivo `IS_READY` se excluye automáticamente del procesamiento (está vacío, solo sirve como señal)

### Ejemplo de estructura:
```
gs://apolo-preavaluos-pdf-dev/
├── CARPETA-1/
│   ├── documento1.pdf    ✅ Procesado
│   ├── documento2.pdf    ✅ Procesado
│   └── IS_READY          ❌ No procesado (solo trigger)
└── CARPETA-2/
    ├── balance.pdf       ✅ Procesado
    └── IS_READY          ❌ No procesado (solo trigger)
```

**Nota**: La detección de "IS_READY" es **case-insensitive**, por lo que funcionan: `IS_READY`, `is_ready`, `Is_Ready`, etc.

---

## PARTE 1: Instalación de Requisitos (Solo una vez)

### 1️⃣ Instalar Google Cloud SDK

**Opción A: Instalador (Recomendado)**
1. Descarga: https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe
2. Ejecuta el instalador
3. Sigue las instrucciones en pantalla
4. ✅ **IMPORTANTE**: Cierra y abre PowerShell de nuevo

**Verificar instalación:**
```powershell
gcloud --version
```

### 2️⃣ Instalar Docker Desktop

1. Descarga: https://www.docker.com/products/docker-desktop
2. Ejecuta el instalador
3. Inicia Docker Desktop
4. ✅ **IMPORTANTE**: Espera a que Docker esté corriendo (icono verde en la barra de tareas)

**Verificar instalación:**
```powershell
docker --version
docker ps
```

---

## PARTE 2: Configuración Inicial de GCP (Solo una vez)

### 1️⃣ Crear Cuenta y Proyecto en GCP

1. Ve a: https://console.cloud.google.com
2. Crea una cuenta (o inicia sesión)
3. Crea un nuevo proyecto:
   - Click en el selector de proyectos (arriba)
   - "Nuevo Proyecto"
   - Nombre: `apolo-procesamiento` (o el que prefieras)
   - ✅ **Anota el PROJECT_ID** (aparece debajo del nombre)

4. Habilita facturación:
   - Menú → Facturación
   - Vincula una cuenta de facturación
   - (Incluye $300 de créditos gratis si es cuenta nueva)

### 2️⃣ Autenticarse en gcloud

```powershell
# Autenticarte con tu cuenta de Google
gcloud auth login

# Esto abrirá un navegador
# Sigue las instrucciones para autorizar gcloud
```

### 3️⃣ Configurar el Proyecto

```powershell
# Reemplaza con tu PROJECT_ID
$PROJECT_ID = "tu-project-id-aqui"

# Configurar como proyecto activo
gcloud config set project $PROJECT_ID

# Configurar región por defecto
gcloud config set run/region us-south1

# Verificar
gcloud config get-value project
gcloud config get-value run/region
```

---

## PARTE 3: Despliegue Automatizado (Cada vez que despliegues)

### Ejecutar el Script de Despliegue Completo

```powershell
# Navegar al directorio del proyecto
cd "ruta\a\tu\proyecto\apolo_procesamiento_inteligente_preavaluo"

# Ejecutar script de despliegue
.\deploy-complete.ps1
```

El script te pedirá:
1. Tu PROJECT_ID
2. Confirmación para continuar

Luego hará automáticamente:
- ✅ Habilitar APIs necesarias
- ✅ Crear bucket de GCS
- ✅ Crear base de datos Firestore
- ✅ Crear service account con permisos
- ✅ Construir imagen Docker
- ✅ Subir imagen a Google Container Registry
- ✅ Desplegar servicio a Cloud Run
- ✅ Darte la URL del servicio

**Tiempo estimado**: 10-15 minutos

---

## PARTE 4: Probar el Servicio

### 1️⃣ Subir un archivo de prueba

```powershell
# Crear un PDF dummy para probar
$pdfContent = "%PDF-1.4`n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj`nxref`n0 2`ntrailer<</Size 2/Root 1 0 R>>`nstartxref`n%%EOF"
$pdfContent | Out-File -FilePath "test.pdf" -Encoding ASCII -NoNewline

# Subir al bucket (reemplaza PROJECT_ID)
$BUCKET = "preavaluos-pdf-tu-project-id"
gsutil cp test.pdf "gs://${BUCKET}/PRE-2025-001/balance_general.pdf"
```

### 2️⃣ Ejecutar Tests

```powershell
# Obtener la URL del servicio (está en deploy-info.json después del despliegue)
$SERVICE_URL = (Get-Content deploy-info.json | ConvertFrom-Json).service_url

# Test individual
.\test-cloudrun.ps1 -ServiceUrl $SERVICE_URL -Mode individual

# Test batch
.\test-cloudrun.ps1 -ServiceUrl $SERVICE_URL -Mode batch
```

### 3️⃣ Ver Logs

```powershell
# Ver logs en tiempo real
gcloud run services logs read apolo-procesamiento-inteligente `
  --region us-south1 `
  --limit 50
```

---

## 🎯 Resumen de Comandos

### Primera vez (Setup completo):
```powershell
# 1. Instalar gcloud SDK y Docker Desktop (manual)

# 2. Autenticarte
gcloud auth login

# 3. Configurar proyecto
$PROJECT_ID = "tu-project-id"
gcloud config set project $PROJECT_ID

# 4. Desplegar
cd "c:\Users\LD_51\Desktop\job\Sarah\apolo_procesamiento_inteligente_preavaluo"
.\deploy-complete.ps1
```

### Redespliegues posteriores:
```powershell
# Solo necesitas esto:
cd "c:\Users\LD_51\Desktop\job\Sarah\apolo_procesamiento_inteligente_preavaluo"
.\deploy-cloudrun.ps1 -Environment prod -ProjectId "tu-project-id"
```

---

## ❓ Solución de Problemas

### Error: "gcloud: command not found"
- Cierra y abre PowerShell de nuevo
- O ejecuta: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")`

### Error: "Docker daemon not running"
- Inicia Docker Desktop
- Espera a que el icono esté verde

### Error: "Permission denied" al crear recursos
- Verifica que tienes permisos de Owner o Editor en el proyecto
- Ve a: IAM & Admin → IAM en la consola de GCP

### Error: "Billing not enabled"
- Ve a: Facturación en la consola de GCP
- Vincula una cuenta de facturación al proyecto

### Error: "API not enabled"
- El script las habilita automáticamente
- O manualmente: Menú → APIs & Services → Enable APIs

---

## 📊 Monitoreo y Gestión

### Ver servicio en la consola:
```
https://console.cloud.google.com/run
```

### Ver logs en la consola:
```
https://console.cloud.google.com/logs
```

### Ver bucket de archivos:
```
https://console.cloud.google.com/storage
```

### Ver base de datos Firestore:
```
https://console.cloud.google.com/firestore
```

---

## 🗑️ Limpieza de Recursos (Opcional)

Cuando ya no necesites el servicio:

```powershell
$PROJECT_ID = "tu-project-id"
$SERVICE_NAME = "apolo-procesamiento-inteligente"
$BUCKET_NAME = "preavaluos-pdf-${PROJECT_ID}"

# Eliminar servicio de Cloud Run
gcloud run services delete $SERVICE_NAME --region us-south1 --quiet

# Eliminar imágenes
gcloud container images delete "gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest" --quiet

# Eliminar bucket (⚠️ esto elimina todos los archivos)
gsutil -m rm -r "gs://${BUCKET_NAME}"

# Eliminar service account
gcloud iam service-accounts delete "apolo-procesamiento-sa@${PROJECT_ID}.iam.gserviceaccount.com" --quiet
```

---

## 🎓 Próximos Pasos

Una vez desplegado exitosamente:

1. ✅ Integrar con tu backend/aplicación
2. ✅ Configurar Cloud Workflows para orquestación
3. ✅ Reemplazar simuladores con Document AI real
4. ✅ Configurar alertas y monitoreo
5. ✅ Implementar CI/CD con Cloud Build

---

**¿Necesitas ayuda?** Consulta `DEPLOY_GUIDE.md` para instrucciones más detalladas.
