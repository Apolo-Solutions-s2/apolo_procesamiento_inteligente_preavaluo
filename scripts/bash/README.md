# 📜 Scripts Bash (Linux/Mac/Git Bash)

Scripts de automatización para construcción, despliegue y pruebas en sistemas Unix.

## 📋 Scripts Disponibles

### 🔨 `build-docker.sh`
Construye imagen Docker localmente.

**Uso**:
```bash
./build-docker.sh
```

**Salida**:
- Imagen: `apolo-procesamiento-inteligente:local-latest`
- Comandos para ejecutar el contenedor

---

### 🚀 `deploy-cloudrun.sh`
Despliegue completo a Google Cloud Run.

**Uso**:
```bash
./deploy-cloudrun.sh [ENVIRONMENT]

# Ejemplos:
./deploy-cloudrun.sh dev
./deploy-cloudrun.sh prod
```

**Variables de entorno opcionales**:
```bash
export GCP_PROJECT_ID="tu-project-id"
export GCP_REGION="us-south1"
export BUCKET_NAME="preavaluos-pdf"
```

**Proceso**:
1. Valida configuración
2. Construye imagen Docker
3. Sube a Google Container Registry
4. Despliega a Cloud Run
5. Verifica salud del servicio

---

### 🧪 `test-cloudrun.sh`
Suite de pruebas para el servicio.

**Uso**:
```bash
./test-cloudrun.sh [SERVICE_URL] [MODE]

# Ejemplos:
./test-cloudrun.sh "http://localhost:8080" individual
./test-cloudrun.sh "https://tu-servicio.run.app" batch
```

**Modos**:
- `individual`: Procesa un documento específico
- `batch`: Procesa carpeta completa

**Tests**:
- Health check
- Procesamiento de documentos
- Manejo de errores
- Validación de respuestas

---

## ⚙️ Configuración Inicial

### 1. Dar permisos de ejecución
```bash
chmod +x *.sh
```

### 2. Instalar dependencias
```bash
# gcloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Docker (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install docker.io

# Docker (macOS con Homebrew)
brew install --cask docker
```

### 3. Autenticar con GCP
```bash
gcloud auth login
gcloud config set project TU_PROJECT_ID
```

---

## 🔄 Flujos de Trabajo

### Primera vez:
```bash
# 1. Configurar
export GCP_PROJECT_ID="tu-project-id"

# 2. Desplegar
./deploy-cloudrun.sh dev

# 3. Probar
SERVICE_URL=$(gcloud run services describe apolo-procesamiento-inteligente \
  --region us-south1 --format 'value(status.url)')
./test-cloudrun.sh "$SERVICE_URL" individual
```

### Desarrollo local:
```bash
# 1. Construir
./build-docker.sh

# 2. Ejecutar
docker run -p 8080:8080 --rm \
  -e BUCKET_NAME=preavaluos-pdf \
  apolo-procesamiento-inteligente:local-latest

# 3. Probar (en otra terminal)
./test-cloudrun.sh "http://localhost:8080" batch
```

### Actualizar servicio:
```bash
./deploy-cloudrun.sh prod
```

---

## 🐛 Solución de Problemas

### Permission denied al ejecutar
```bash
chmod +x *.sh
```

### Python3 no encontrado (para tests)
```bash
# Ubuntu/Debian
sudo apt-get install python3

# macOS
brew install python3
```

### curl no encontrado
```bash
# Ubuntu/Debian
sudo apt-get install curl

# macOS (ya incluido)
```

---

## 📚 Ver También

- Script equivalentes Windows: `../powershell/`
- Documentación completa: `../../docs/`
- Guía de despliegue: `../../docs/DEPLOY_GUIDE.md`
