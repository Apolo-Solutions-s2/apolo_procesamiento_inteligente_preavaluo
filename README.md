# Apolo - Procesamiento Inteligente de Documentos Financieros

Solución de procesamiento inteligente de documentos financieros para **Apolo Solutions**.

## 📋 Descripción

**Propósito**
Cloud Function que procesa documentos financieros desde Google Cloud Storage (GCS) para el módulo de preavalúos de Apolo. La función realiza dos etapas principales:
- ✅ **Clasificación**: Identifica el tipo de documento (Estados de Resultados, Balance General, Registros Patronales)
- ✅ **Extracción**: Extrae campos estructurados según el tipo de documento

**Contexto**
Se ejecuta como Cloud Function (HTTP) serverless en GCP bajo el enfoque de orquestación con Cloud Workflows. La función lista documentos de un bucket GCS, simula clasificación y extracción, y retorna resultados con trazabilidad y referencias de ubicación dentro de los documentos.

## 🚀 Características Técnicas

| Aspecto | Especificación |
|--------|----------------|
| **Tipo de Recurso** | Cloud Function (HTTP) |
| **Lenguaje** | Python 3.11+ |
| **Framework** | Flask + functions-framework |
| **Patrón** | Orquestado por Cloud Workflows (OIDC) |
| **Región** | us-south1 (Dallas) - configurable |
| **Almacenamiento** | Google Cloud Storage (GCS) |
| **Seguridad** | Autenticación OIDC desde Workflows |

## 📦 Dependencias Principales

- **functions-framework** (v3.x) - Para ejecutar como Cloud Function
- **Flask** - Servidor HTTP
- **google-cloud-storage** (v2.10.0+) - Para listar y acceder a objetos en GCS

## 🔍 Comportamiento Esperado

**Entrada (Request JSON)**
```json
{
  "folder_prefix": "preavaluo-12345/documentos",
  "preavaluo_id": "preavaluo-12345",
  "extensions": [".pdf"],
  "max_items": 500
}
```

**Flujo de Ejecución**
1. Lista todos los objetos en GCS bajo el `folder_prefix` indicado
2. Filtra por extensiones permitidas (default: `.pdf`)
3. Por cada documento:
   - Ejecuta clasificación simulada (retorna tipo de documento y confianza)
   - Ejecuta extracción simulada (retorna campos y metadatos con referencias de página)
   - Registra progreso y timestamps UTC
4. Retorna resultado consolidado con todos los documentos procesados

**Salida (Response JSON)**
```json
{
  "status": "processed",
  "preavaluo_id": "preavaluo-12345",
  "bucket": "preavaluos-pdf",
  "folder_prefix": "preavaluo-12345/documentos",
  "document_count": 3,
  "results": [
    {
      "file_name": "documento1.pdf",
      "gcs_uri": "gs://preavaluos-pdf/preavaluo-12345/documentos/documento1.pdf",
      "classification": {
        "document_type": "EstadoDeResultados",
        "confidence": 0.95
      },
      "extraction": {
        "fields": {"Ingresos": 25000.50, "Egresos": 12000.75, "Fecha": "2025-12-01"},
        "metadata": {
          "page_refs": [{"page": 1, "bbox": {"x1": 100, "y1": 200, "x2": 300, "y2": 220}}],
          "processor_version": "sim-v1",
          "decision_path": "SIMULATED"
        }
      },
      "processed_at": "2025-12-03T14:30:00.123456"
    }
  ]
}
```

**Tipos de Documentos Soportados**
- `EstadoDeResultados` - Documento financiero de ingresos y egresos
- `BalanceGeneral` - Documento de activos y pasivos
- `RegistrosPatronales` - Documento de registros de empleadores

## 📁 Estructura del Repositorio

```
procesamiento-inteligente/
├── apolo_procesamiento_inteligente.py  # Función principal (worker entrypoint)
├── requirements.txt                     # Dependencias Python
├── .gitignore                           # Archivos ignorados
├── README.md                            # Este archivo
├── LICENSE                              # Licencia MIT
└── terraform/                           # Configuración de IaC (NO incluida en git)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── dev/, qa/, prod/                 # Configuración por ambiente
```

## 🛠️ Instalación Local

```bash
# Clonar el repositorio
git clone https://github.com/svasquezsoldig/apolo_procesamiento_inteligente_preavaluo.git
cd apolo_procesamiento_inteligente_preavaluo

# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt
```

## 🚀 Ejecución Local

```bash
# Ejecutar la Cloud Function localmente con functions-framework
functions-framework --target=document_processor --debug --port=8080
```

Luego, en otra terminal:
```bash
# Hacer un request de prueba
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{
    "folder_prefix": "preavaluo-12345/documentos",
    "preavaluo_id": "preavaluo-12345",
    "extensions": [".pdf"],
    "max_items": 10
  }'
```

## 📋 Variables de Entorno

| Variable | Descripción | Default |
|----------|-------------|---------|
| `BUCKET_NAME` | Nombre del bucket GCS | `preavaluos-pdf` |

## 🌐 Despliegue en GCP (Cloud Functions)

## 🌐 Despliegue en GCP (Cloud Functions)

**Nota**: Los archivos `terraform/` están disponibles para configuración por ambiente (dev, qa, prod).

```powershell
# Desplegar usando Terraform
cd terraform\dev
terraform init
terraform apply -var-file="terraform.tfvars"
```

Repite para `terraform\qa` y `terraform\prod`.

**Variables necesarias en `terraform.tfvars`**:
- `project_id` - ID del proyecto GCP
- `service_name` - Nombre de la Cloud Function
- `container_image` - URL de la imagen de contenedor (si aplica)
- `bucket_name` - Nombre del bucket GCS a procesar
- `invoker_identity` - Service account que invoca la función

## 🔄 Orquestación con Cloud Workflows

La función es invocada por `workflow.yaml`, que orquesta el flujo completo:

```yaml
callProcessor:
  call: http.post
  args:
    url: ${processor_url}
    auth:
      type: OIDC
      audience: ${processor_audience}
    body:
      preavaluo_id: ${preavaluo_id}
      folder_prefix: ${folder_prefix}
```

**Características del Workflow**:
- Autenticación OIDC (sin credenciales estáticas)
- Reintentos automáticos según HTTP defaults
- Pasa parámetros desde el contexto del flujo
- Retorna resultado procesado al workflow llamador

## 🐳 Construcción de Imagen (si aplica)

```powershell
# Construir imagen localmente
docker build -t apolo-processor:latest .

# Subir a Artifact Registry
docker tag apolo-processor:latest gcr.io/PROJECT_ID/apolo-processor:latest
docker push gcr.io/PROJECT_ID/apolo-processor:latest
```

## 📝 Estructura de Archivos

```
procesamiento-inteligente/
├── apolo_procesamiento_inteligente.py  # Cloud Function principal
│   ├── simulate_classification()       # Clasifica documento (simulado)
│   ├── simulate_extraction()           # Extrae campos (simulado)
│   ├── _list_objects()                 # Lista objetos de GCS
│   └── document_processor()            # Entrypoint HTTP
├── workflow.yaml                       # Orquestación con Cloud Workflows
├── requirements.txt                    # Dependencias (Flask, GCS, functions-framework)
├── LICENSE                             # MIT License
├── README.md                           # Este archivo
└── terraform/                          # Configuración IaC por ambiente
    ├── main.tf                         # Recursos Cloud Functions
    ├── variables.tf                    # Variables
    ├── outputs.tf                      # Salidas
    └── dev/, qa/, prod/                # Ambientes (backend + tfvars)
```

## 🔐 Seguridad

- **Autenticación OIDC**: Cloud Workflows autentica a Cloud Function sin exponer credenciales
- **IAM**: Service accounts granulares para acceso a GCS y otros recursos
- **No hay credenciales estáticas**: Todas las credenciales se manejan a través de GCP IAM

## ⚠️ Comportamiento Actual (Simulado)

**Nota**: Las funciones de clasificación y extracción actualmente son simuladas para demostración.

- `simulate_classification()` - Retorna un tipo de documento aleatorio con confianza entre 80-99%
- `simulate_extraction()` - Retorna campos genéricos según el tipo de documento
- No realiza procesamiento real de PDF o acceso a Document AI (pendiente implementación)

## 🤝 Contribución

1. Fork el repositorio
2. Crea una rama: `git checkout -b feature/nueva-feature`
3. Commit: `git commit -am 'Añade nueva feature'`
4. Push: `git push origin feature/nueva-feature`
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo licencia MIT. Ver `LICENSE` para detalles.

---

**Apolo Solutions** © 2025. Todos los derechos reservados.
