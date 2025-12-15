# 📚 Índice de Documentación - Versión 2.0

## 🎯 Documentación Principal

### Para Empezar
1. **[SUMMARY_OF_CHANGES.md](SUMMARY_OF_CHANGES.md)** ⭐ EMPEZAR AQUÍ
   - Resumen ejecutivo de todos los cambios
   - Comparativa versión 1.0 vs 2.0
   - Checklist de deployment
   - Métricas de éxito

2. **[README_V2.md](README_V2.md)**
   - Guía completa de la versión 2.0
   - Arquitectura actualizada
   - Flujo de procesamiento
   - Ejemplos de uso
   - Configuración de desarrollo local

3. **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)**
   - Paso a paso para migrar de v1 a v2
   - Configuración de Eventarc
   - Setup de Document AI
   - Creación de DLQ
   - Scripts de migración de datos
   - Plan de rollback

---

## 📁 Estructura del Proyecto

```
apolo_procesamiento_inteligente_preavaluo/
├── 📄 Código Principal
│   ├── apolo_procesamiento_inteligente_v2.py  ⭐ NUEVA VERSIÓN
│   └── apolo_procesamiento_inteligente.py      (Original - Backup)
│
├── 🐳 Docker & Deployment
│   ├── Dockerfile                              (Actualizado para v2)
│   ├── docker-compose.yml
│   └── requirements.txt                        (Actualizado con Document AI)
│
├── 📚 Documentación
│   ├── README_V2.md                           ⭐ LEER PRIMERO
│   ├── SUMMARY_OF_CHANGES.md                  ⭐ CAMBIOS DETALLADOS
│   ├── MIGRATION_GUIDE.md                     ⭐ GUÍA DE MIGRACIÓN
│   ├── INDEX.md                               (Este archivo)
│   └── README.md                              (Original)
│
├── 📖 Documentation/
│   ├── ARCHITECTURE.md                        Arquitectura del sistema
│   ├── DEPLOY_GUIDE.md                        Guía de despliegue
│   ├── DEPLOYMENT_CHECKLIST.md                Checklist pre-deploy
│   ├── FIRESTORE_SCHEMA.md                    Esquema de Firestore
│   ├── GCP_COMMANDS.md                        Comandos útiles de GCP
│   ├── INFRASTRUCTURE.md                      Infraestructura completa
│   ├── PROJECT_STATUS.md                      Estado del proyecto
│   ├── QUICKSTART.md                          Inicio rápido
│   ├── TESTING.md                             Guía de testing
│   └── README.md                              Índice de documentación
│
├── 🚀 Scripts de Deployment
│   ├── scripts/bash/
│   │   ├── deploy-v2.sh                      ⭐ DEPLOY LINUX/MAC
│   │   ├── deploy-cloudrun.sh
│   │   ├── build-docker.sh
│   │   ├── test-cloudrun.sh
│   │   └── README.md
│   │
│   └── scripts/powershell/
│       ├── deploy-v2.ps1                     ⭐ DEPLOY WINDOWS
│       ├── deploy-cloudrun.ps1
│       ├── build-docker.ps1
│       ├── test-cloudrun.ps1
│       └── README.md
│
├── 🏗️ Infraestructura (Terraform)
│   └── infrastructure/terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── deploy.sh
│       ├── deploy.ps1
│       ├── README.md
│       └── env/
│           ├── dev.tfvars
│           ├── qa.tfvars
│           ├── prod.tfvars
│           └── example.tfvars
│
└── 📊 Diagramas
    └── diagrams/
        ├── architecture-dataflow.mmd
        ├── firestore-schema-simple.mmd
        ├── firestore-schema.mmd
        ├── generate_diagrams.py
        ├── INSTALLATION_GUIDE.md
        └── README.md
```

---

## 🎓 Guías por Rol

### 👨‍💻 Para Desarrolladores

**Setup Local:**
1. [README_V2.md - Sección "Desarrollo Local"](README_V2.md#-configuración-de-desarrollo-local)
2. `docker-compose.yml` - Levantar servicios locales
3. [TESTING.md](Documentation/TESTING.md) - Guía de testing

**Entender el Código:**
1. `apolo_procesamiento_inteligente_v2.py` - Código principal (bien documentado)
2. [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) - Arquitectura del sistema
3. [FIRESTORE_SCHEMA.md](Documentation/FIRESTORE_SCHEMA.md) - Esquema de datos

**Debugging:**
1. [GCP_COMMANDS.md](Documentation/GCP_COMMANDS.md) - Comandos útiles
2. Logs en Cloud Logging
3. DLQ para errores recurrentes

---

### 🚀 Para DevOps

**Deployment Nueva Versión:**
1. [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) ⭐ **ESENCIAL**
2. `scripts/bash/deploy-v2.sh` o `scripts/powershell/deploy-v2.ps1`
3. [DEPLOYMENT_CHECKLIST.md](Documentation/DEPLOYMENT_CHECKLIST.md)

**Configuración de Infraestructura:**
1. `infrastructure/terraform/` - IaC completo
2. [INFRASTRUCTURE.md](Documentation/INFRASTRUCTURE.md)
3. [DEPLOY_GUIDE.md](Documentation/DEPLOY_GUIDE.md)

**Monitoreo:**
1. Cloud Logging queries en [README_V2.md](README_V2.md#-observabilidad)
2. DLQ subscription: `apolo-preavaluo-dlq-monitor`
3. Cloud Monitoring dashboards

---

### 📊 Para Product Managers

**Entender el Sistema:**
1. [SUMMARY_OF_CHANGES.md](SUMMARY_OF_CHANGES.md) - Resumen ejecutivo
2. [README_V2.md - Sección "Arquitectura"](README_V2.md#-arquitectura-actualizada)
3. [PROJECT_STATUS.md](Documentation/PROJECT_STATUS.md)

**Capacidades del Sistema:**
1. [README_V2.md - Sección "Flujo"](README_V2.md#-flujo-de-procesamiento)
2. Procesamiento automático al detectar `is_ready`
3. 60 documentos procesados en ~5-10 minutos (paralelo)

---

### 🎯 Para Usuarios Finales

**Cómo Usar el Sistema:**
1. [QUICKSTART.md](Documentation/QUICKSTART.md)
2. [README_V2.md - Sección "Flujo"](README_V2.md#-flujo-de-procesamiento)

**Pasos Simplificados:**
```bash
# 1. Subir PDFs
gsutil cp *.pdf gs://preavaluos-pdf/MI-CARPETA/

# 2. Activar procesamiento
gsutil cp /dev/null gs://preavaluos-pdf/MI-CARPETA/is_ready

# 3. Ver resultados en Firestore Console
# folios > MI-CARPETA > documentos
```

---

## 🔍 Guías por Tarea

### Tarea: "Quiero deployar por primera vez"
1. ✅ [MIGRATION_GUIDE.md - Sección "Configuración de Document AI"](MIGRATION_GUIDE.md#5-document-ai-processors)
2. ✅ [MIGRATION_GUIDE.md - Sección "Variables de Entorno"](MIGRATION_GUIDE.md#3-variables-de-entorno-requeridas)
3. ✅ `scripts/bash/deploy-v2.sh` o `scripts/powershell/deploy-v2.ps1`
4. ✅ [DEPLOYMENT_CHECKLIST.md](Documentation/DEPLOYMENT_CHECKLIST.md)

### Tarea: "Entender qué cambió en v2"
1. ✅ [SUMMARY_OF_CHANGES.md](SUMMARY_OF_CHANGES.md) ⭐
2. ✅ [README_V2.md - Sección "Cambios Implementados"](README_V2.md#-cambios-implementados)

### Tarea: "Migrar datos de v1 a v2"
1. ✅ [MIGRATION_GUIDE.md - Sección "Script de Migración"](MIGRATION_GUIDE.md#4-esquema-firestore-actualizado)

### Tarea: "Configurar Document AI"
1. ✅ [MIGRATION_GUIDE.md - Sección "Document AI"](MIGRATION_GUIDE.md#5-document-ai-processors)
2. ✅ [README_V2.md - Sección "Configuración de Document AI"](README_V2.md#-configuración-de-document-ai)

### Tarea: "Debugging de errores"
1. ✅ [README_V2.md - Sección "Manejo de Errores"](README_V2.md#-manejo-de-errores)
2. ✅ [GCP_COMMANDS.md](Documentation/GCP_COMMANDS.md)
3. ✅ DLQ: `gcloud pubsub subscriptions pull apolo-dlq-monitor --auto-ack`

### Tarea: "Entender el esquema de Firestore"
1. ✅ [FIRESTORE_SCHEMA.md](Documentation/FIRESTORE_SCHEMA.md)
2. ✅ [README_V2.md - Esquema Firestore](README_V2.md#5-esquema-firestore-jerárquico)

### Tarea: "Ver logs y monitoreo"
1. ✅ [README_V2.md - Sección "Observabilidad"](README_V2.md#-observabilidad)
2. ✅ [GCP_COMMANDS.md](Documentation/GCP_COMMANDS.md)

### Tarea: "Probar localmente sin GCP"
1. ✅ [README_V2.md - Desarrollo Local](README_V2.md#-configuración-de-desarrollo-local)
2. ✅ `docker-compose.yml`
3. ✅ Comentar integraciones reales en el código

---

## 📋 Checklists

### ✅ Checklist de Deployment Inicial

**Pre-requisitos:**
- [ ] Cuenta de GCP con proyecto activo
- [ ] gcloud CLI instalado y configurado
- [ ] Docker instalado
- [ ] Permisos de Owner o Editor en el proyecto

**Configuración:**
- [ ] Document AI Classifier creado y entrenado
- [ ] Document AI Extractor creado y entrenado
- [ ] Variables de entorno configuradas
- [ ] Service account creada
- [ ] Bucket de GCS creado
- [ ] Firestore database creada

**Deployment:**
- [ ] Ejecutar script de deployment
- [ ] Verificar Cloud Run service
- [ ] Verificar Eventarc trigger
- [ ] Verificar DLQ topic y subscription
- [ ] Probar con carpeta de test
- [ ] Verificar resultados en Firestore

**Post-Deployment:**
- [ ] Configurar alertas en Cloud Monitoring
- [ ] Documentar credenciales y IDs
- [ ] Capacitar al equipo
- [ ] Definir SLAs y SLOs

---

### ✅ Checklist de Troubleshooting

**El procesamiento no se activa:**
- [ ] Verificar que el archivo sea exactamente `is_ready` (sin extensión)
- [ ] Verificar Eventarc trigger: `gcloud eventarc triggers list`
- [ ] Ver logs del trigger
- [ ] Verificar permisos del service account

**Documentos no se procesan:**
- [ ] Verificar que sean PDFs válidos (magic bytes `%PDF-`)
- [ ] Ver logs de Cloud Run
- [ ] Verificar configuración de Document AI (PROCESSOR_IDs)
- [ ] Revisar DLQ para errores recurrentes

**Errores de permisos:**
- [ ] Verificar roles del service account
- [ ] Verificar que Cloud Run service tiene permisos de invocación
- [ ] Verificar acceso a bucket de GCS

**Resultados incorrectos:**
- [ ] Verificar entrenamiento de Document AI processors
- [ ] Revisar confidence scores en Firestore
- [ ] Validar que los PDFs sean de buena calidad

---

## 🔗 Enlaces Útiles

### Documentación Externa
- [Document AI Documentation](https://cloud.google.com/document-ai/docs)
- [Eventarc Documentation](https://cloud.google.com/eventarc/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Pub/Sub Documentation](https://cloud.google.com/pubsub/docs)

### GCP Console
- [Cloud Run Services](https://console.cloud.google.com/run)
- [Eventarc Triggers](https://console.cloud.google.com/eventarc)
- [Firestore Console](https://console.cloud.google.com/firestore)
- [Cloud Logging](https://console.cloud.google.com/logs)
- [Cloud Monitoring](https://console.cloud.google.com/monitoring)
- [Document AI](https://console.cloud.google.com/ai/document-ai)
- [Pub/Sub Topics](https://console.cloud.google.com/cloudpubsub/topic)

---

## 📞 Soporte y Contacto

### Para Preguntas Técnicas
1. Revisar logs en Cloud Logging
2. Consultar DLQ para errores recurrentes
3. Revisar documentación relevante (ver índice arriba)
4. Contactar al equipo de DevOps

### Para Reportar Issues
- **Logs**: Incluir logs de Cloud Logging
- **Context**: Folio ID, bucket, folder_prefix
- **Steps**: Pasos para reproducir
- **Expected**: Comportamiento esperado
- **Actual**: Comportamiento observado

---

## 🔄 Actualizaciones

### Versión 2.0.0 (Actual)
**Fecha**: Diciembre 15, 2025  
**Estado**: ✅ Completado - Listo para deployment  
**Alineación**: 100% con especificación oficial  

**Cambios principales:**
- ✅ Activación por Eventarc
- ✅ Document AI real
- ✅ Procesamiento paralelo
- ✅ Generation de GCS
- ✅ Esquema Firestore jerárquico
- ✅ DLQ con Pub/Sub
- ✅ Reintentos con backoff exponencial

### Versión 1.0 (Original)
**Estado**: 🟡 Deprecated - Usar solo como referencia  
**Archivo**: `apolo_procesamiento_inteligente.py` (backup)  
**README**: `README.md` (original)

---

## 🎯 Quick Links

| Necesito... | Ir a... |
|-------------|---------|
| Entender los cambios | [SUMMARY_OF_CHANGES.md](SUMMARY_OF_CHANGES.md) |
| Deployar por primera vez | [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) |
| Guía completa v2.0 | [README_V2.md](README_V2.md) |
| Scripts de deployment | `scripts/bash/deploy-v2.sh` o `scripts/powershell/deploy-v2.ps1` |
| Ver arquitectura | [ARCHITECTURE.md](Documentation/ARCHITECTURE.md) |
| Configurar Document AI | [MIGRATION_GUIDE.md#5](MIGRATION_GUIDE.md#5-document-ai-processors) |
| Debugging | [README_V2.md#manejo-de-errores](README_V2.md#-manejo-de-errores) |
| Comandos útiles | [GCP_COMMANDS.md](Documentation/GCP_COMMANDS.md) |

---

**Última actualización**: Diciembre 15, 2025  
**Versión del proyecto**: 2.0.0  
**Estado**: ✅ Production Ready (requiere config de Document AI)
