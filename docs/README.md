# 📚 Documentación - Apolo Procesamiento Inteligente

Esta carpeta contiene toda la documentación del proyecto.

## 📄 Documentos Disponibles

### 🚀 [QUICKSTART.md](QUICKSTART.md)
**Para empezar rápidamente**

Guía paso a paso para usuarios nuevos:
- Instalación de requisitos
- Configuración inicial de GCP
- Primer despliegue
- Primeras pruebas

**Lee esto primero si es tu primera vez.**

---

### 📖 [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md)
**Guía técnica completa de despliegue**

Documentación detallada del proceso de despliegue:
- Cada paso explicado en detalle
- Todos los comandos con ejemplos
- Configuración de recursos GCP
- Troubleshooting avanzado

**Consulta esto para entender a fondo el proceso.**

---

### 🧪 [TESTING.md](TESTING.md)
**Guía completa de pruebas**

Cómo probar el microservicio:
- Pruebas locales (Docker)
- Pruebas en Cloud Run
- Casos de prueba recomendados
- Checklist de validación
- Interpretación de resultados

**Usa esto para validar que todo funciona correctamente.**

---

### 📊 [PROJECT_STATUS.md](PROJECT_STATUS.md)
**Estado actual del proyecto**

Información sobre:
- Características implementadas
- Archivos necesarios vs opcionales
- Próximos pasos
- Roadmap de desarrollo
- Métricas de éxito

**Consulta esto para saber qué está listo y qué falta.**

---

## 🗺️ Navegación Rápida

### ¿Empezando desde cero?
1. Lee [QUICKSTART.md](QUICKSTART.md)
2. Instala requisitos (gcloud SDK + Docker)
3. Ejecuta `../scripts/powershell/deploy-complete.ps1`
4. Sigue [TESTING.md](TESTING.md) para probar

### ¿Necesitas desplegar?
1. Consulta [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md)
2. Usa `../scripts/powershell/deploy-cloudrun.ps1`
3. Verifica con `../scripts/powershell/test-cloudrun.ps1`

### ¿Quieres probar?
1. Lee [TESTING.md](TESTING.md)
2. Ejecuta `../scripts/powershell/test-cloudrun.ps1`
3. Revisa logs en GCP Console

### ¿Dudas sobre el proyecto?
1. Revisa [PROJECT_STATUS.md](PROJECT_STATUS.md)
2. Consulta el README principal: `../README.md`
3. Revisa scripts: `../scripts/README.md`

---

## 📑 Otros Recursos

### En la raíz del proyecto:
- `../README.md` - Documentación principal del microservicio
- `../workflow.yaml` - Definición de Cloud Workflows
- `../Dockerfile` - Configuración de la imagen Docker

### Scripts de automatización:
- `../scripts/README.md` - Índice de todos los scripts
- `../scripts/powershell/` - Scripts para Windows
- `../scripts/bash/` - Scripts para Linux/Mac

### Infraestructura como código:
- `../infrastructure/terraform/` - Configuración Terraform (opcional)

---

## 🔍 Búsqueda Rápida

**¿Cómo...?**

| Pregunta | Documento | Sección |
|----------|-----------|---------|
| ...instalo los requisitos? | QUICKSTART.md | Parte 1 |
| ...creo un proyecto en GCP? | QUICKSTART.md | Parte 2 |
| ...despliego por primera vez? | DEPLOY_GUIDE.md | Pasos 1-12 |
| ...pruebo el servicio? | TESTING.md | Paso 13 |
| ...veo los logs? | TESTING.md | Monitoreo |
| ...actualizo el servicio? | DEPLOY_GUIDE.md | Comandos Útiles |
| ...elimino recursos? | DEPLOY_GUIDE.md | Limpieza |
| ...sé qué archivos son necesarios? | PROJECT_STATUS.md | Archivos |
| ...configuro Workflows? | PROJECT_STATUS.md | Fase 4 |

---

## 📝 Formato de la Documentación

Todos los documentos siguen estas convenciones:

- ✅ Checkmark: Tarea completada o funcionalidad implementada
- ⏳ Reloj: Pendiente o en progreso
- ⚠️ Advertencia: Información importante o precaución
- 💡 Bombilla: Tip o recomendación
- 🔧 Llave: Configuración o setup
- 🚀 Cohete: Despliegue o lanzamiento
- 🧪 Tubo de ensayo: Pruebas o testing
- 📊 Gráfico: Monitoreo o métricas

---

## 🔄 Mantener Actualizada

Al hacer cambios al proyecto:

1. **Código nuevo**: Actualiza `PROJECT_STATUS.md`
2. **Nuevo script**: Actualiza `../scripts/README.md`
3. **Cambio en proceso**: Actualiza `DEPLOY_GUIDE.md`
4. **Nueva prueba**: Actualiza `TESTING.md`

---

## 📞 Soporte

Si encuentras errores en la documentación o algo no está claro:

1. Revisa los comentarios en los scripts
2. Consulta el código fuente
3. Revisa los logs de GCP
4. Busca en la documentación oficial de GCP

---

**Última actualización**: 2025-12-04  
**Versión de documentación**: 1.0.0
