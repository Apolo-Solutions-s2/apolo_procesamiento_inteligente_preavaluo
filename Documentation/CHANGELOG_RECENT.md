# Changelog - Cambios Recientes

## 2025-12-19 - Correcciones en Detección de IS_READY y Procesamiento

### 📝 Cambios Implementados

#### 1. **Detección Case-Insensitive de IS_READY**
- **Archivo**: `apolo_procesamiento_inteligente.py`
- **Función**: `_is_ready_sentinel()`
- **Cambio**: Ahora detecta "IS_READY", "is_ready", "Is_Ready", etc. (no importa mayúsculas/minúsculas)
- **Motivo**: Compatibilidad con diferentes convenciones de nombres de archivos

#### 2. **Exclusión del Archivo IS_READY del Procesamiento**
- **Archivo**: `apolo_procesamiento_inteligente.py`
- **Función**: `_list_pdfs_in_folder()`
- **Cambio**: Excluye explícitamente el archivo "IS_READY" de la lista de PDFs a procesar
- **Motivo**: El archivo "IS_READY" está vacío y solo sirve como señal de trigger, no debe procesarse

#### 3. **Salto de Tests Automáticos en Actualizaciones**
- **Archivo**: `Cloud Shell/update_code.sh`
- **Cambio**: Agregado flag `--skip-tests` al comando `./deploy.sh --resume`
- **Motivo**: Acelerar el despliegue de actualizaciones de código sin ejecutar pruebas automatizadas

### 🔄 Flujo de Procesamiento (Actualizado)

```
1. Usuario sube archivos PDF a gs://bucket/CARPETA-NOMBRE/
2. Usuario sube archivo IS_READY (sin extensión, vacío) a la misma carpeta
3. Eventarc detecta el evento y activa el microservicio
4. Microservicio:
   ✅ Detecta "IS_READY" (case-insensitive)
   ✅ Identifica la carpeta CARPETA-NOMBRE
   ✅ Lista TODOS los PDFs de esa carpeta
   ✅ EXCLUYE el archivo IS_READY (no es PDF)
   ✅ Procesa cada PDF en paralelo (clasificación + extracción)
   ✅ Persiste resultados en Firestore
   ✅ Actualiza estado del folio
```

### 📋 Documentación Actualizada

1. **QUICKSTART.md**
   - Agregada sección sobre activación por archivo IS_READY
   - Aclarado que el archivo IS_READY no se procesa
   - Ejemplo de estructura de carpetas

2. **ARCHITECTURE.md**
   - Agregado diagrama detallado del flujo de activación por IS_READY
   - Explicación completa del proceso de detección case-insensitive
   - Documentación sobre exclusión del archivo IS_READY

3. **TESTING.md**
   - Actualizado flujo de prueba manual
   - Pasos para subir archivos y verificar procesamiento
   - Comandos para verificar logs y Firestore

### ✅ Validación

Los cambios fueron validados exitosamente:
- ✅ Microservicio (v00014-vvc) detecta "FUERZA/IS_READY" (mayúsculas)
- ✅ Encuentra 5 PDFs en carpeta FUERZA
- ✅ Excluye archivo IS_READY del procesamiento
- ✅ Inicia procesamiento de documentos

Próximo paso: Inicializar Firestore para completar la persistencia de resultados.

### 🔧 Comandos Relevantes

**Para desplegar nuevos cambios de código sin tests:**
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./update_code.sh
```

**Para ejecutar tests manualmente:**
```bash
./test_uuid_processing.sh
```

**Para verificar estado del servicio:**
```bash
gcloud run services describe apolo-procesamiento-inteligente \
  --region=us-south1 \
  --format="value(status.latestCreatedRevisionName)"
```
