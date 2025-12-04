# 📜 Scripts PowerShell (Windows)

Scripts de automatización para construcción, despliegue y pruebas en Windows PowerShell.

## 📋 Scripts Disponibles

### 🔨 `build-docker.ps1`
Construye imagen Docker localmente.

**Uso**:
```powershell
.\build-docker.ps1
```

**Salida**:
- Imagen: `apolo-procesamiento-inteligente:local-latest`
- Comandos para ejecutar el contenedor

---

### 🚀 `deploy-cloudrun.ps1`
Despliegue completo a Google Cloud Run con todas las opciones.

**Uso**:
```powershell
.\deploy-cloudrun.ps1 `
  -Environment dev `
  -ProjectId "tu-project-id" `
  -Region "us-south1" `
  -BucketName "preavaluos-pdf"
```

**Parámetros**:
| Parámetro | Descripción | Requerido | Default |
|-----------|-------------|-----------|---------|
| `Environment` | Entorno (dev/qa/prod) | No | `dev` |
| `ProjectId` | ID del proyecto GCP | Sí* | `$env:GCP_PROJECT_ID` |
| `Region` | Región de despliegue | No | `us-south1` |
| `BucketName` | Nombre del bucket | No | `preavaluos-pdf` |

\* Requerido si no está en `$env:GCP_PROJECT_ID`

**Proceso**:
1. ✅ Valida configuración y dependencias
2. ✅ Construye imagen Docker
3. ✅ Sube a Google Container Registry
4. ✅ Despliega a Cloud Run
5. ✅ Configura variables de entorno
6. ✅ Verifica salud del servicio

---

### 🎬 `deploy-complete.ps1`
Setup completo desde cero (incluye creación de recursos).

**Uso**:
```powershell
.\deploy-complete.ps1
```

El script solicitará el PROJECT_ID interactivamente.

**Proceso completo**:
1. ✅ Verifica gcloud CLI y Docker
2. ✅ Autentica con GCP (si es necesario)
3. ✅ Configura proyecto
4. ✅ Habilita APIs necesarias
5. ✅ Crea bucket de GCS
6. ✅ Crea base de datos Firestore
7. ✅ Crea service account con permisos
8. ✅ Construye y sube imagen Docker
9. ✅ Despliega a Cloud Run
10. ✅ Guarda información en `deploy-info.json`

**Cuándo usar**: Primera vez que despliegas en un proyecto GCP nuevo.

---

### 🧪 `test-cloudrun.ps1`
Suite completa de pruebas para el servicio.

**Uso**:
```powershell
# Probar servicio local
.\test-cloudrun.ps1 `
  -ServiceUrl "http://localhost:8080" `
  -Mode individual

# Probar servicio en Cloud Run
.\test-cloudrun.ps1 `
  -ServiceUrl "https://tu-servicio.run.app" `
  -Mode batch
```

**Parámetros**:
| Parámetro | Descripción | Default |
|-----------|-------------|---------|
| `ServiceUrl` | URL del servicio | `http://localhost:8080` |
| `Mode` | `individual` o `batch` | `individual` |

**Tests ejecutados**:
1. ✅ Health Check (GET request)
2. ✅ Procesamiento según modo seleccionado
3. ✅ Validación de manejo de errores
4. ✅ Verificación de estructura de respuesta

**Salida**:
- Resultados coloreados por consola
- Detalles de respuestas JSON
- Validación de status codes

---

## ⚙️ Configuración Inicial

### 1. Habilitar ejecución de scripts
```powershell
# Ejecutar como Administrador
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Configurar variables de entorno (opcional)
```powershell
$env:GCP_PROJECT_ID = "tu-project-id"
$env:GCP_REGION = "us-south1"
$env:BUCKET_NAME = "preavaluos-pdf"
```

### 3. Instalar dependencias
- **Google Cloud SDK**: https://cloud.google.com/sdk/docs/install
- **Docker Desktop**: https://www.docker.com/products/docker-desktop

### 4. Autenticar con GCP
```powershell
gcloud auth login
gcloud config set project TU_PROJECT_ID
```

---

## 🔄 Flujos de Trabajo

### Primera vez (Setup completo):
```powershell
# 1. Ejecutar setup completo
.\deploy-complete.ps1

# 2. Cargar información del despliegue
$deployInfo = Get-Content deploy-info.json | ConvertFrom-Json
$SERVICE_URL = $deployInfo.service_url

# 3. Probar
.\test-cloudrun.ps1 -ServiceUrl $SERVICE_URL -Mode individual
```

### Desarrollo local:
```powershell
# 1. Construir imagen
.\build-docker.ps1

# 2. Ejecutar contenedor (en otra terminal)
docker run -p 8080:8080 --rm `
  -e BUCKET_NAME=preavaluos-pdf `
  apolo-procesamiento-inteligente:local-latest

# 3. Probar
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode batch
```

### Redespliegue (después de cambios):
```powershell
# Opción 1: Con parámetros explícitos
.\deploy-cloudrun.ps1 `
  -Environment prod `
  -ProjectId "mi-proyecto-123"

# Opción 2: Con variables de entorno
$env:GCP_PROJECT_ID = "mi-proyecto-123"
.\deploy-cloudrun.ps1 -Environment prod
```

---

## 🎯 Ejemplos Prácticos

### Desarrollo Iterativo
```powershell
# Bucle de desarrollo
while ($true) {
    # 1. Hacer cambios en el código
    code .\apolo_procesamiento_inteligente.py
    
    # 2. Construir y probar localmente
    .\build-docker.ps1
    docker run -p 8080:8080 --rm apolo-procesamiento-inteligente:local-latest
    
    # 3. En otra terminal: probar
    .\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080"
    
    # 4. Si está OK, desplegar
    $confirm = Read-Host "¿Desplegar a Cloud Run? (s/n)"
    if ($confirm -eq "s") {
        .\deploy-cloudrun.ps1 -Environment dev
    }
}
```

### CI/CD Manual
```powershell
# Script de integración continua manual
$ErrorActionPreference = "Stop"

Write-Host "🔍 Validando código..." -ForegroundColor Cyan
python -m py_compile apolo_procesamiento_inteligente.py

Write-Host "🔨 Construyendo imagen..." -ForegroundColor Cyan
.\build-docker.ps1

Write-Host "🧪 Probando localmente..." -ForegroundColor Cyan
# Ejecutar contenedor en background
$containerId = docker run -d -p 8080:8080 apolo-procesamiento-inteligente:local-latest
Start-Sleep -Seconds 5
.\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode individual
docker stop $containerId

Write-Host "🚀 Desplegando a Cloud Run..." -ForegroundColor Cyan
.\deploy-cloudrun.ps1 -Environment prod -ProjectId "mi-proyecto"

Write-Host "✅ Pipeline completado" -ForegroundColor Green
```

---

## 🐛 Solución de Problemas

### Error: "No se puede ejecutar scripts"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "gcloud: command not found"
1. Instala gcloud SDK
2. Reinicia PowerShell
3. O actualiza PATH manualmente:
```powershell
$env:Path += ";C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin"
```

### Error: "Docker daemon not running"
1. Inicia Docker Desktop
2. Espera a que el icono esté verde
3. Verifica: `docker ps`

### Error: "Unauthorized" al subir imagen
```powershell
gcloud auth configure-docker gcr.io
```

### Script se cuelga en "Construyendo imagen"
- Docker puede estar usando mucha memoria
- Cierra otras aplicaciones
- Aumenta memoria asignada a Docker (Settings → Resources)

---

## 📊 Monitoreo Post-Despliegue

### Ver logs del servicio
```powershell
gcloud run services logs read apolo-procesamiento-inteligente `
  --region us-south1 `
  --limit 50
```

### Ver información del servicio
```powershell
gcloud run services describe apolo-procesamiento-inteligente `
  --region us-south1
```

### Ver métricas
```powershell
# Abrir en navegador
$PROJECT_ID = gcloud config get-value project
Start-Process "https://console.cloud.google.com/run/detail/us-south1/apolo-procesamiento-inteligente/metrics?project=$PROJECT_ID"
```

---

## 📚 Ver También

- Scripts equivalentes Linux/Mac: `../bash/`
- Documentación completa: `../../docs/`
- Guía rápida: `../../docs/QUICKSTART.md`
- Guía de despliegue: `../../docs/DEPLOY_GUIDE.md`
- Guía de pruebas: `../../docs/TESTING.md`

---

**Tip**: Agrega alias a tu perfil de PowerShell para acceso rápido:
```powershell
# Editar perfil
notepad $PROFILE

# Agregar alias
Set-Alias build .\scripts\powershell\build-docker.ps1
Set-Alias deploy .\scripts\powershell\deploy-cloudrun.ps1
Set-Alias test .\scripts\powershell\test-cloudrun.ps1
```
