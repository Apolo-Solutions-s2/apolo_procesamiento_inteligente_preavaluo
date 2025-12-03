# Apolo - Procesamiento Inteligente de Documentos Financieros

Solución de procesamiento inteligente de documentos financieros para **Apolo Solutions**.

## 📋 Descripción

**Propósito**
Microservicio orquestador del módulo de preavalúos Apolo para ejecutar el procesamiento inteligente de documentos financieros estandarizados a PDF/A. Realiza tres etapas principales:
- ✅ **Clasificación**: Identifica el tipo de documento
- ✅ **Extracción**: Extrae campos estructurados
- ✅ **Persistencia**: Almacena resultados con trazabilidad

**Contexto**
Diseñado para correr en GCP bajo un enfoque serverless y de alta resiliencia. El microservicio se ejecuta como worker (sin endpoint público) y es invocado por flujos (Cloud Workflows / scheduler) siguiendo un patrón asíncrono.

## 🚀 Características Técnicas

| Aspecto | Especificación |
|--------|----------------|
| **Tipo de Recurso** | Cloud Run Job (worker backend-only) |
| **Lenguaje** | Python 3.11+ |
| **Patrón** | Asíncrono, versionamiento, reintentos y DLQ |
| **Región** | us-south1 (Dallas) - configurable |
| **Seguridad** | IAM con service accounts (sin credenciales estáticas) |
| **Secretos** | Secret Manager para credenciales |
| **Persistencia** | Firestore para resultados y trazabilidad |

## 📦 Dependencias Externas

- **Document AI Classifier** (API directa o gateway interno)
- **Document AI Custom Extractor** (API directa o gateway interno)
- **Firestore** (para resultados y trazabilidad)

## 🔍 Comportamiento Esperado

- **Idempotencia**: Reintentos no crean resultados duplicados (usa `preavaluo_id` y claves deterministas)
- **Reintentos y DLQ**: Fallas transitorias se reintentan; errores irreparables van a DLQ
- **Trazabilidad**: Registra eventos, timestamps UTC, versión del procesador, decision path

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

## 🌐 Despliegue en GCP (Terraform)

**Nota**: Los archivos `terraform/` no se incluyen en este repositorio. Configúralos según tu proyecto.

```powershell
cd terraform\dev
terraform init
terraform apply -var-file="terraform.tfvars"
```

Repite para `terraform\qa` y `terraform\prod`.

**Variables necesarias en `terraform.tfvars`**:
- `project_id` - ID del proyecto GCP
- `service_name` - Nombre del servicio
- `container_image` - URL de la imagen de contenedor
- `invoker_identity` - Identidad autorizada

## 🐳 Construcción y Deploy de Imagen

```powershell
# Construir imagen localmente (si es necesario)
docker build -t apolo-processor:latest .

# Subir a Artifact Registry (requiere configuración previa)
docker tag apolo-processor:latest gcr.io/PROJECT_ID/apolo-processor:latest
docker push gcr.io/PROJECT_ID/apolo-processor:latest
```

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
