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
