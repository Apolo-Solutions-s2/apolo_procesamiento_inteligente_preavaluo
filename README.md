**Descripción**
- **Propósito**: Microservicio orquestador del módulo de preavalúos Apolo para ejecutar el procesamiento inteligente de documentos financieros estandarizados a PDF/A. Realiza tres etapas principales: clasificación, extracción estructural y persistencia con trazabilidad.
- **Contexto**: Diseñado para correr en GCP bajo un enfoque serverless y de alta resiliencia. El microservicio debe ejecutarse como worker (sin endpoint público) y ser invocado por flujos (Cloud Workflows / scheduler) siguiendo patrón asíncrono.

**Especificaciones Técnicas**
- **Tipo recomendado**: `Cloud Run Job` (worker backend-only). Evita exponer endpoint HTTP y facilita cumplimiento de "sin exterior".
- **Lenguaje**: `Python 3.11`.
- **Patrón**: Asíncrono, versionamiento, reintentos y DLQ coordinado por el workflow.
- **Región**: `us-south1` (Dallas) - ajustar según proyecto.
- **Seguridad**:
  - **Service-to-service**: IAM por service accounts (tokens gestionados, sin llaves). No se gestionan credenciales estáticas en el código.
  - **Secretos**: `Secret Manager` para credenciales/secretos (notar: Harness se encarga del pipeline/secretos y del aterrizaje de políticas de seguridad; aquí sólo documentamos el uso).
- **Persistencia / Trazabilidad**: Firestore para persistir resultados, estados y metadatos de procesamiento (timestamps, preavaluo_id, decision path, processor_version, etc.).
- **Dependencias externas**:
  - Document AI Classifier (vía API directa o gateway interno)
  - Document AI Custom Extractor (vía API directa o gateway interno)
  - Firestore (para resultados y trazabilidad)

**Comportamiento esperado**
- Idempotencia: reintentos no deben crear resultados duplicados (usar preavaluo_id y/o claves deterministas en Firestore).
- Reintentos y DLQ: las fallas transitorias re-intentar; errores irreparables deben quedar en DLQ y marcar estado en Firestore.
- Trazabilidad: registrar eventos y metadata (actor, timestamp UTC, versión del processor, decision path, ubicación de la imagen/documento procesado).

**Estructura del repositorio (relevante)**
- `apolo_procesamiento_inteligente.py`: función principal simulada (entrypoint para el worker).
- `requirements.txt`: dependencias Python.
- `terraform/`: configuración de IaC para despliegues dev/qa/prod.

**Despliegue (Infraestructura como Código)**
Los archivos Terraform ya existentes están en `terraform/` y organizados por entorno (`dev/`, `qa/`, `prod/`).

- Preparar buckets GCS para el backend de Terraform (uno por entorno). Ejemplo: `my-terraform-state-dev`, `my-terraform-state-qa`, `my-terraform-state-prod`.

Comandos básicos (PowerShell):
```powershell
# Entrar al entorno (ejemplo dev)
cd terraform\dev
terraform init
terraform apply -var-file="terraform.tfvars"
```
Repetir para `terraform\qa` y `terraform\prod`.

Nota: los `terraform.tfvars` contienen variables como `project_id`, `service_name`, `container_image` e `invoker_identity`. Sustituir por valores reales del proyecto.

Recomendación técnica: cambiar el recurso Terraform a `google_cloud_run_job` si se quiere seguir la recomendación oficial de Cloud Run Job (actualmente el código de ejemplo crea un `google_cloud_run_service`). Puedo actualizar los archivos Terraform a Cloud Run Job si lo deseas.

**Construir y subir la imagen de contenedor**
La CI/CD la gestiona Harness por tus indicaciones; aquí están los pasos manuales para build/push locales (útiles para pruebas):

```powershell
# Autenticarse y preparar (gcloud instalado y autenticado)
gcloud auth configure-docker --quiet
# Construir imagen (ejemplo para GCR)
docker build -t gcr.io/<PROJECT_ID>/document-processor:latest .
# Subir imagen
docker push gcr.io/<PROJECT_ID>/document-processor:latest
```

Si usas Artifact Registry sustituir `gcr.io` por el repositorio correspondiente.

**Variables y configuración de runtime**
- `ENVIRONMENT`: `dev|qa|prod`
- `PREAVALUO_ID` (ej. provisto por el invocador)
- Configuración de conexión a Firestore: `GOOGLE_CLOUD_PROJECT` y permisos IAM del service account que ejecuta el job.

Para pruebas locales con credenciales de desarrollador (solo en dev/test):
- Exportar `GOOGLE_APPLICATION_CREDENTIALS` apuntando al JSON de una cuenta de servicio con permisos mínimos (Firestore, Cloud Run admin solo si vas a desplegar localmente, etc.).

**Pruebas unitarias**
- Alcance: inclusión de tests unitarios que cubran la lógica de orquestación, reintentos en memoria, y parsing/serialización de resultados. No incluimos pruebas de integración con Document AI o Firestore (estas se dejan como pruebas de integración separadas o mocks).
- Ejecutar tests locales (PowerShell):
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pytest -q
```
- Recomendación: usar `pytest` y `pytest-mock` para mockear llamadas a Document AI y Firestore.

**Observabilidad y logs**
- Usar `logging` en Python y exportar logs a Cloud Logging.
- Emitir métricas clave como: `documents_processed`, `processing_time_seconds`, `failed_extractions`.

**Buenas prácticas / Consideraciones**
- Idempotencia basada en `preavaluo_id` y marcas de versión.
- Retries con backoff exponencial y límites configurables; errores permanentes deben migrarse a DLQ y marcarse en Firestore.
- Versionamiento de imagen y ofuscación de secrets: Harness debe inyectar las variables/secretos; no codificar secretos en Terraform ni en el contenedor.
- Asegurar principle of least privilege: el service account que ejecuta el Job sólo debe tener permisos mínimos sobre Firestore y Document AI.

**Siguientes pasos recomendados**
- ¿Deseas que actualice los `terraform/*` para usar `google_cloud_run_job` en lugar de `google_cloud_run_service`? (Puedo hacerlo y dejar ejemplos de `job` + IAM).
- Puedo añadir un conjunto mínimo de `pytest` y fixtures para el archivo `apolo_procesamiento_inteligente.py`.

**Contacto / mantenimiento**
- Este README describe la intención arquitectural y los pasos operativos mínimos. Para integración con Harness (pipelines, secret injection, políticas), coordinar con el equipo de plataforma que gestiona Harness en tu organización.

---
Archivo generado: `README.md`. Si quieres, actualizo los `terraform/` para crear un `Cloud Run Job` y añado tests unitarios de ejemplo.
