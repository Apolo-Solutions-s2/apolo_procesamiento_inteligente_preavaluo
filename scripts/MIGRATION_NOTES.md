# Guía de Migración - Apolo Procesamiento Inteligente

## 🆕 Cambios Recientes (Diciembre 2025)

### 🔄 Actualizaciones de Configuración

#### Región GCP
- **Antes**: Región por defecto `us`
- **Ahora**: Región por defecto `us-south1`
- **Impacto**: Todos los servicios GCP ahora apuntan a `us-south1`
- **Acción**: Actualizar variables de entorno si usas región diferente

#### Requirements
- **Antes**: Versiones genéricas (`>=`)
- **Ahora**: Versiones específicas y actualizadas
- **Beneficio**: Mayor estabilidad y seguridad
- **Acción**: `pip install -r requirements.txt` para actualizar

#### Logs Estructurados
- **Antes**: `event_type` genérico (`doc_processing_start`)
- **Ahora**: `event_type` específico (`folio_{folio_id}_doc_{doc_id}_processing_start`)
- **Beneficio**: Mejor trazabilidad en procesamiento paralelo
- **Acción**: Actualizar queries de logs si las tienes automatizadas

#### Esquema Firestore
- **Antes**: Esquema basado en `runs/`
- **Ahora**: Esquema jerárquico `folios/{folioId}/documentos/{docId}/extracciones/{extractionId}`
- **Beneficio**: Alineado con especificación del microservicio
- **Acción**: Migrar datos existentes si aplica (ver documentación)

#### Idempotencia
- **Antes**: No implementada completamente
- **Ahora**: Completa por `generation` y estado de carpeta
- **Beneficio**: Evita re-procesamiento innecesario
- **Acción**: Ninguna, es automática

---

# Guía de Migración - Scripts Simplificados

## 🔄 Cambios Realizados

Se han simplificado los scripts de despliegue para optimizar su uso en **Google Cloud Shell**.

### Scripts Eliminados (Redundantes):
- ❌ `scripts/bash/` - Scripts individuales de bash
- ❌ `scripts/powershell/` - Scripts de PowerShell para Windows
- ❌ `scripts/build-and-push.sh` - Script legacy
- ❌ `scripts/build-and-push.ps1` - Script legacy
- ❌ `scripts/deploy.ps1` - Script legacy PowerShell

### Scripts Nuevos (Consolidados):
- ✅ `scripts/setup.sh` - Configuración inicial única
- ✅ `scripts/deploy.sh` - Despliegue completo todo-en-uno

## 📝 Notas Importantes

### Antes (Scripts antiguos):
```bash
# Múltiples pasos, múltiples scripts
./bash/build-docker.sh
./bash/deploy-cloudrun.sh dev
./bash/test-cloudrun.sh
```

### Ahora (Scripts simplificados):
```bash
# Un solo comando
./deploy.sh dev apolo-dev-project
```

## 🌐 Optimizado para Google Cloud Shell

Los nuevos scripts están diseñados específicamente para **Google Cloud Shell**:

1. **No requieren Docker local** - Usan Cloud Build
2. **No requieren configuración de autenticación** - Ya está configurada en Cloud Shell
3. **Instalación automática de dependencias** - Terraform si es necesario
4. **Feedback visual mejorado** - Progreso claro y coloreado

## 🚀 Cómo Migrar

Si tenías scripts personalizados que llamaban a los antiguos:

### Antes:
```bash
cd scripts/bash
./deploy-cloudrun.sh dev
```

### Ahora:
```bash
cd scripts
./deploy.sh dev
```

## 💡 Beneficios

1. **Menos archivos** - De ~15 scripts a 2 scripts principales
2. **Más simple** - Un comando lo hace todo
3. **Más rápido** - Cloud Build es más rápido que Docker local
4. **Más confiable** - Sin problemas de configuración local
5. **Mejor documentado** - README actualizado y conciso

## 📚 Documentación Actualizada

- [README de Scripts](README.md) - Guía principal
- [ARCHITECTURE.md](../Documentation/ARCHITECTURE.md) - Arquitectura general
- [DEPLOY_GUIDE.md](../Documentation/DEPLOY_GUIDE.md) - Guía completa de despliegue
