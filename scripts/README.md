# Scripts de Despliegue para Google Cloud Shell

Este directorio contiene scripts simplificados y optimizados para ejecutar desde **Google Cloud Shell** (ambiente web de GCP).

## 📋 Scripts Disponibles

### 1. `setup.sh` - Configuración Inicial
Configura el proyecto GCP por primera vez: habilita APIs, crea service accounts y configura el backend de Terraform.

```bash
./setup.sh [PROJECT_ID]
```

**Ejemplo:**
```bash
./setup.sh apolo-dev-project
```

**Qué hace:**
- Habilita todas las APIs necesarias
- Crea el bucket para el estado de Terraform
- Crea el service account principal
- Asigna roles IAM necesarios

### 2. `deploy.sh` - Despliegue Completo
Despliega la aplicación completa: construye la imagen Docker, despliega infraestructura con Terraform y verifica el despliegue.

```bash
./deploy.sh [ENVIRONMENT] [PROJECT_ID]
```

**Ejemplos:**
```bash
./deploy.sh dev apolo-dev-project
./deploy.sh prod apolo-prod-project
```

**Qué hace:**
1. Configura el proyecto GCP
2. Construye y sube la imagen Docker usando Cloud Build
3. Despliega infraestructura con Terraform
4. Verifica el servicio Cloud Run
5. Muestra resumen de recursos desplegados

## 🚀 Inicio Rápido

### Primera vez (Configuración inicial):

```bash
# 1. Clonar el repositorio (en Cloud Shell)
git clone [REPO_URL]
cd apolo_procesamiento_inteligente_preavaluo/scripts

# 2. Dar permisos de ejecución
chmod +x setup.sh deploy.sh

# 3. Ejecutar setup inicial
./setup.sh apolo-dev-project

# 4. Desplegar aplicación
./deploy.sh dev apolo-dev-project
```

### Despliegues siguientes:

```bash
# Solo ejecutar deploy
./deploy.sh dev apolo-dev-project
```

## 🌍 Ambientes

Los scripts soportan tres ambientes:
- **dev**: Desarrollo (recursos mínimos)
- **qa**: Quality Assurance (recursos medios)
- **prod**: Producción (recursos completos)

Cada ambiente tiene su archivo de variables en `infrastructure/terraform/env/`:
- `dev.tfvars`
- `qa.tfvars`
- `prod.tfvars`

## 📝 Variables de Entorno

Los scripts usan las siguientes variables (opcionales):

```bash
export GCP_REGION=us-south1  # Región predeterminada
```

## ⚠️ Notas Importantes

1. **Google Cloud Shell**: Estos scripts están optimizados para ejecutarse en Google Cloud Shell, no requieren Docker ni herramientas locales
2. **Cloud Build**: Se usa Cloud Build en lugar de Docker local para construcción de imágenes
3. **Permisos**: Asegúrate de tener permisos de Owner o Editor en el proyecto
4. **Costos**: El script de setup habilita APIs que pueden generar costos
5. **Scripts antiguos eliminados**: Se han removido carpetas `bash/` y `powershell/` con scripts redundantes

## 🔧 Troubleshooting

### Error: "Permission denied"
```bash
chmod +x setup.sh deploy.sh
```

### Error: "Project not set"
Especifica el PROJECT_ID explícitamente:
```bash
./deploy.sh dev TU_PROJECT_ID
```

### Error: "Terraform backend bucket not found"
Ejecuta primero el script de setup:
```bash
./setup.sh TU_PROJECT_ID
```

### Error al construir imagen
Cloud Build necesita la API habilitada. El script `setup.sh` la habilita automáticamente.

## 📚 Documentación Adicional

- [Documentación de Arquitectura](../Documentation/ARCHITECTURE.md)
- [Guía de Despliegue Completa](../Documentation/DEPLOY_GUIDE.md)
- [Infraestructura Terraform](../infrastructure/terraform/README.md)

---

**Última actualización**: 2025-12-15  
**Versión**: 2.0.0 - Simplificado para Google Cloud Shell

## 🚀 RECOMENDADO: Despliegue Desde Cloud Shell

**¿Primera vez o quieres la forma más fácil?**

Usa el script único para Cloud Shell que hace todo automáticamente:

📄 **[`deploy-cloudshell.sh`](deploy-cloudshell.sh)** + **[Guía](CLOUDSHELL_DEPLOY.md)**

**3 pasos simples:**
1. Abre Google Cloud Shell
2. Copia y pega el contenido de `deploy-cloudshell.sh`
3. Presiona Enter

✅ **Garantiza**:
- Región: **us-south1** (Dallas)
- Base de datos: **apolo-preavaluos-dev**
- Colección: **apolo_procesamiento**
- Tests automáticos incluidos

👉 **[Ver guía completa de Cloud Shell →](CLOUDSHELL_DEPLOY.md)**

---

## 📂 Estructura Completa

```
scripts/
├── deploy-cloudshell.sh      # ⭐ Script único para Cloud Shell (RECOMENDADO)
├── CLOUDSHELL_DEPLOY.md      # 📖 Guía completa de Cloud Shell
│
├── powershell/               # Scripts para Windows PowerShell
│   ├── build-docker.ps1
│   ├── deploy-cloudrun.ps1
│   ├── deploy-complete.ps1
│   └── test-cloudrun.ps1
│
└── bash/                     # Scripts para Linux/Mac/Git Bash
    ├── build-docker.sh
    ├── deploy-cloudrun.sh
    └── test-cloudrun.sh
```

---

## 🪟 Scripts PowerShell (Windows)

### `build-docker.ps1`
**Propósito**: Construir imagen Docker localmente para pruebas

**Uso**:
```powershell
.\scripts\powershell\build-docker.ps1
```

**Funcionalidad**:
- Construye imagen Docker con tag `local-latest`
- Usa platform `linux/amd64` (compatible con Cloud Run)
- Muestra comandos para ejecutar el contenedor localmente

**Cuándo usar**: Para probar cambios localmente antes de desplegar

---

### `deploy-cloudrun.ps1`
**Propósito**: Despliegue completo a Google Cloud Run (con todas las opciones)

**Uso**:
```powershell
.\scripts\powershell\deploy-cloudrun.ps1 `
  -Environment dev `
  -ProjectId "tu-project-id" `
  -Region "us-south1" `
  -BucketName "preavaluos-pdf"
```

**Parámetros**:
- `-Environment`: Entorno (dev, qa, prod)
- `-ProjectId`: ID del proyecto GCP
- `-Region`: Región de despliegue (default: us-south1)
- `-BucketName`: Nombre del bucket GCS (default: preavaluos-pdf)

**Funcionalidad**:
1. Valida requisitos (gcloud, docker)
2. Configura autenticación
3. Construye imagen Docker
4. Sube a Google Container Registry
5. Despliega a Cloud Run
6. Retorna URL del servicio
7. Ejecuta verificación de salud

**Cuándo usar**: Para despliegues completos con todas las validaciones

---

### `deploy-complete.ps1`
**Propósito**: Setup completo desde cero (primera vez)

**Uso**:
```powershell
.\scripts\powershell\deploy-complete.ps1
```

El script preguntará interactivamente por el PROJECT_ID

**Funcionalidad**:
1. Verifica gcloud CLI y Docker
2. Autentica con GCP
3. Habilita APIs necesarias
4. Crea bucket de GCS
5. Crea base de datos Firestore
6. Crea service account con permisos
7. Construye y sube imagen
8. Despliega a Cloud Run
9. Guarda información en `deploy-info.json`

**Cuándo usar**: Primera vez que despliegas el proyecto en un proyecto GCP nuevo

---

### `test-cloudrun.ps1`
**Propósito**: Ejecutar suite de pruebas contra el servicio

**Uso**:
```powershell
# Probar servicio local
.\scripts\powershell\test-cloudrun.ps1 `
  -ServiceUrl "http://localhost:8080" `
  -Mode individual

# Probar servicio en Cloud Run
.\scripts\powershell\test-cloudrun.ps1 `
  -ServiceUrl "https://tu-servicio.run.app" `
  -Mode batch
```

**Parámetros**:
- `-ServiceUrl`: URL del servicio a probar (local o Cloud Run)
- `-Mode`: Tipo de prueba
  - `individual`: Procesa un documento específico
  - `batch`: Procesa carpeta completa

**Tests que ejecuta**:
1. ✅ Health Check (GET request)
2. ✅ Procesamiento individual o batch (según modo)
3. ✅ Validación de manejo de errores
4. ✅ Verificación de estructura de respuesta

**Cuándo usar**: Para validar que el servicio funciona correctamente

---

## 🐧 Scripts Bash (Linux/Mac)

### `build-docker.sh`
Equivalente a `build-docker.ps1` para sistemas Unix

**Uso**:
```bash
chmod +x scripts/bash/build-docker.sh
./scripts/bash/build-docker.sh
```

---

### `deploy-cloudrun.sh`
Equivalente a `deploy-cloudrun.ps1` para sistemas Unix

**Uso**:
```bash
chmod +x scripts/bash/deploy-cloudrun.sh

# Con variables de entorno
export GCP_PROJECT_ID="tu-project-id"
./scripts/bash/deploy-cloudrun.sh dev

# O directo
./scripts/bash/deploy-cloudrun.sh dev
```

---

### `test-cloudrun.sh`
Equivalente a `test-cloudrun.ps1` para sistemas Unix

**Uso**:
```bash
chmod +x scripts/bash/test-cloudrun.sh

# Test individual
./scripts/bash/test-cloudrun.sh "http://localhost:8080" individual

# Test batch
./scripts/bash/test-cloudrun.sh "https://tu-servicio.run.app" batch
```

---

## 🔄 Flujo de Trabajo Típico

### Primera vez (Setup completo):
```powershell
# Windows
.\scripts\powershell\deploy-complete.ps1
```

```bash
# Linux/Mac
export GCP_PROJECT_ID="tu-project-id"
./scripts/bash/deploy-cloudrun.sh dev
```

### Desarrollo local:
```powershell
# 1. Construir imagen
.\scripts\powershell\build-docker.ps1

# 2. Ejecutar localmente (manual)
docker run -p 8080:8080 --rm apolo-procesamiento-inteligente:local-latest

# 3. Probar
.\scripts\powershell\test-cloudrun.ps1 -ServiceUrl "http://localhost:8080" -Mode individual
```

### Redespliegue (después de cambios):
```powershell
# Windows
.\scripts\powershell\deploy-cloudrun.ps1 -Environment prod -ProjectId "tu-project-id"
```

```bash
# Linux/Mac
./scripts/bash/deploy-cloudrun.sh prod
```

---

## 🔧 Requisitos

### Para todos los scripts:
- Google Cloud SDK (gcloud CLI)
- Docker Desktop
- Cuenta de GCP con proyecto creado
- Permisos de Owner/Editor en el proyecto

### Para PowerShell:
- Windows PowerShell 5.1+ o PowerShell Core 7+
- Ejecución de scripts habilitada: `Set-ExecutionPolicy RemoteSigned`

### Para Bash:
- Bash 4.0+
- curl y python3 (para tests)
- Permisos de ejecución: `chmod +x script.sh`

---

## 📝 Variables de Entorno

Los scripts usan estas variables de entorno (opcionales):

```powershell
# PowerShell
$env:GCP_PROJECT_ID = "tu-project-id"
$env:GCP_REGION = "us-south1"
$env:BUCKET_NAME = "preavaluos-pdf"
```

```bash
# Bash
export GCP_PROJECT_ID="tu-project-id"
export GCP_REGION="us-south1"
export BUCKET_NAME="preavaluos-pdf"
```

---

## 🐛 Troubleshooting

### Script no se ejecuta (PowerShell)
```powershell
# Permitir ejecución de scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Script no tiene permisos (Bash)
```bash
# Dar permisos de ejecución
chmod +x scripts/bash/*.sh
```

### Error: "gcloud: command not found"
- Instala gcloud SDK: https://cloud.google.com/sdk/docs/install
- Reinicia la terminal después de instalar

### Error: "docker: command not found"
- Instala Docker Desktop: https://www.docker.com/products/docker-desktop
- Asegúrate de que Docker está corriendo

---

## 📚 Documentación Adicional

Para más información detallada:
- **Guía de Inicio**: `docs/QUICKSTART.md`
- **Guía de Despliegue**: `docs/DEPLOY_GUIDE.md`
- **Guía de Pruebas**: `docs/TESTING.md`
- **Estado del Proyecto**: `docs/PROJECT_STATUS.md`

---

**Última actualización**: 2025-12-04  
**Versión**: 1.0.0
