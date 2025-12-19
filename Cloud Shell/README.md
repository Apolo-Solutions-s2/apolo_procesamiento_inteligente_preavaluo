# Cloud Shell Scripts

This folder contains deployment and testing scripts for the Apolo Document Processing Service to be run in Google Cloud Shell.

## � Activación del Servicio

El servicio **apolo-procesamiento-inteligente** se activa automáticamente cuando subes un archivo llamado **IS_READY** (sin extensión) a cualquier carpeta del bucket `apolo-preavaluos-pdf-dev`.

### Flujo:
```
1. Sube archivos PDF → gs://apolo-preavaluos-pdf-dev/MI-CARPETA/doc1.pdf
2. Sube archivo IS_READY → gs://apolo-preavaluos-pdf-dev/MI-CARPETA/IS_READY
3. Eventarc detecta automáticamente y activa el trigger
4. Microservicio procesa TODOS los PDFs de la carpeta
5. Archivo IS_READY se excluye automáticamente (está vacío)
```

**Nota**: La detección de "IS_READY" es **case-insensitive** (funciona con mayúsculas y minúsculas)

---

## 📁 Available Scripts

### 🚀 deploy.sh
**Complete deployment script** - Sets up all GCP infrastructure and deploys the service

**Usage:**
```bash
# Full deployment from scratch
./deploy.sh

# Resume interrupted deployment
./deploy.sh --resume

# Skip tests (for code updates)
./deploy.sh --skip-tests

# Show help
./deploy.sh --help
```

**Features:**
- Enables required GCP APIs
- Creates service account with proper IAM roles and Eventarc permissions
- Sets up Cloud Storage bucket with versioning
- Configures Eventarc trigger for GCS finalization events
- Deploys Cloud Run service with all environment variables
- Runs automated tests (unless --skip-tests)
- Provides comprehensive summary and usage instructions

---

### ⚡ update_code.sh
**Code update script** - Fast deployment of code changes (NEW!)

**Usage:**
```bash
# Update code from GitHub and redeploy
./update_code.sh

# Show help
./update_code.sh --help
```

**Features:**
- Fetches latest code from GitHub (branch main)
- Discards local Cloud Shell changes
- Redeployes Cloud Run service automatically
- **Skips tests by default** (faster updates)
- Ideal for iterative development

**This is the recommended way to update after code changes!**

---

### 🧪 test_uuid_processing.sh
**UUID folder processing test script** - Validates the document processing service

**Usage:**
```bash
# Basic test (creates UUID folder, processes PDFs)
./test_uuid_processing.sh

# Test with automatic cleanup
./test_uuid_processing.sh --cleanup

# Test specific project
./test_uuid_processing.sh --project my-project-id

# Show help
./test_uuid_processing.sh --help
```

**What it tests:**
- ✓ UUID folder structure preservation
- ✓ Multiple PDF uploads
- ✓ IS_READY marker upload (triggers processing) - case-insensitive
- ✓ PDF validation and processing
- ✓ Correct handling of file types
- ✓ Log entries with folder_uuid context
- ✓ Output folder creation in correct structure

---

### ⚙️ update_env_vars.sh
**Environment variables update utility** - Quickly update Cloud Run service configuration

**Usage:**
```bash
# Interactive mode
./update_env_vars.sh

# Automatic mode (no prompts)
./update_env_vars.sh --auto

# Show help
./update_env_vars.sh --help
```

**Updates:**
- GCP_PROJECT_ID
- PROCESSOR_LOCATION
- CLASSIFIER_PROCESSOR_NAME
- ER_EXTRACTOR_PROCESSOR_NAME
- ESF_EXTRACTOR_PROCESSOR_NAME
- DLQ_TOPIC_NAME
- MAX_CONCURRENT_DOCS
- MAX_RETRIES

---

## 🎯 Quick Start Guide

### First Time Setup
```bash
# Clone and navigate to repository
cd ~/apolo_procesamiento_inteligente_preavaluo

# Pull latest code
git pull origin main

# Set execute permissions on scripts
cd "Cloud Shell"
chmod +x *.sh

# Deploy
./deploy.sh
```

### After Making Code Changes (RECOMMENDED - FASTER)
```bash
# Just run the update script - it pulls latest code and redeploys!
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
chmod +x update_code.sh
./update_code.sh
```
This handles everything: git pull, code update, and deployment (no tests by default)

### After Making Code Changes (Manual Method)
```bash
# Navigate to repository
cd ~/apolo_procesamiento_inteligente_preavaluo

# Discard any local Cloud Shell changes and pull latest
git fetch origin
git reset --hard origin/main

# Set permissions and deploy
cd "Cloud Shell"
chmod +x *.sh
./deploy.sh --resume --skip-tests
```

### Run Tests
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
./test_uuid_processing.sh
```

### Update Configuration (if needed)
```bash
./update_env_vars.sh --auto
```

---

## 🌐 Environment Variables

All scripts support the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_ID` | Current gcloud project | GCP Project ID |
| `REGION` | `us-south1` | GCP Region (Cloud Run, Storage, Eventarc) |
| `SERVICE_NAME` | `apolo-procesamiento-inteligente` | Cloud Run service name |
| `BUCKET_NAME` | `apolo-preavaluos-pdf-dev` | GCS bucket name |
| `DLQ_TOPIC_NAME` | `apolo-preavaluo-dlq` | Pub/Sub DLQ topic |

### Service-Specific Environment Variables

The Cloud Run service uses these additional environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `GCP_PROJECT_ID` | Project ID | GCP Project ID for service |
| `PROCESSOR_LOCATION` | `us-south1` | Document AI processor location |
| `CLASSIFIER_PROCESSOR_NAME` | `apolo-preavaluo-clasificador-dev` | Document classifier processor |
| `ER_EXTRACTOR_PROCESSOR_NAME` | `apolo-preavaluo-er-extractor-dev` | ER document extractor processor |
| `ESF_EXTRACTOR_PROCESSOR_NAME` | `apolo-preavaluo-esfextractor-dev` | ESF document extractor processor |
| `DLQ_TOPIC_NAME` | `apolo-preavaluo-dlq` | Dead letter queue topic |
| `MAX_CONCURRENT_DOCS` | `8` | Maximum concurrent document processing |
| `MAX_RETRIES` | `3` | Maximum retry attempts per document |

**Example:**
```bash
PROJECT_ID=my-project REGION=us-south1 ./deploy.sh
```

---

## 📋 Typical Workflow

### After Pushing Code Changes to GitHub
```bash
# 1. Navigate to repository root
cd ~/apolo_procesamiento_inteligente_preavaluo

# 2. Discard local Cloud Shell changes and get latest code
git fetch origin
git reset --hard origin/main

# 3. Navigate to Cloud Shell folder and set permissions
cd "Cloud Shell"
chmod +x *.sh

# 4. Redeploy service (will rebuild container with new code)
./deploy.sh --resume

# 5. Test the updated service
./test_uuid_processing.sh
```

### Development/Testing Cycle
```bash
# Edit code locally, commit, and push to GitHub
# (do this on your local machine)

# Then in Cloud Shell:
cd ~/apolo_procesamiento_inteligente_preavaluo
git reset --hard origin/main  # Get latest code
cd "Cloud Shell"
chmod +x *.sh
./deploy.sh --resume          # Redeploy
./test_uuid_processing.sh     # Verify
```

### Production Deployment
```bash
# 1. Deploy with specific project
PROJECT_ID=apolo-prod-12345 ./deploy.sh

# 2. Verify with test
PROJECT_ID=apolo-prod-12345 ./test_uuid_processing.sh --cleanup

# 3. Monitor logs
gcloud run services logs tail apolo-procesamiento-inteligente \
  --region=us-south1 \
  --project=apolo-prod-12345
```

---

## 🛠️ Troubleshooting

### Git merge conflicts when pulling
```bash
# This happens when you have local changes in Cloud Shell
cd ~/apolo_procesamiento_inteligente_preavaluo
git stash                    # Save local changes
git pull origin main         # Pull latest
# Or discard local changes:
git reset --hard origin/main # Discard local changes and use GitHub version
```

### Permission denied when running scripts
```bash
cd ~/apolo_procesamiento_inteligente_preavaluo/Cloud\ Shell
chmod +x *.sh               # Set execute permissions
./deploy.sh                 # Now you can run
```

### Deployment fails during Cloud Run build
```bash
# Resume from where it stopped
./deploy.sh --resume
```

### Service exists but env vars are wrong
```bash
# Update just the environment variables
./update_env_vars.sh --auto
```

### Tests fail
```bash
# Check service logs
gcloud run services logs tail apolo-procesamiento-inteligente --region=us-south1

# Check service status
gcloud run services describe apolo-procesamiento-inteligente --region=us-south1

# Verify bucket exists
gsutil ls gs://apolo-preavaluos-pdf-dev

# Check Eventarc trigger
gcloud eventarc triggers list --location=us-south1
```

### Document AI processor issues
```bash
# Verify processor exists and is accessible
gcloud documentai processors list --location=us-south1

# Check processor health
gcloud documentai processors describe apolo-preavaluo-clasificador-dev \
  --location=us-south1 \
  --format="value(state)"
```

### Eventarc trigger not firing
```bash
# Check trigger configuration
gcloud eventarc triggers describe apolo-procesamiento-trigger --location=us-south1

# Verify service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)" \
  --filter="bindings.members:apolo-procesamiento-sa@$PROJECT_ID.iam.gserviceaccount.com"
```

### Need to clean up everything
```bash
PROJECT_ID=$(gcloud config get-value project)

gcloud run services delete apolo-procesamiento-inteligente --region=us-south1 --quiet
gsutil -m rm -r gs://apolo-preavaluos-pdf-dev
gcloud eventarc triggers delete apolo-procesamiento-trigger --location=us-south1 --quiet
gcloud iam service-accounts delete apolo-procesamiento-sa@${PROJECT_ID}.iam.gserviceaccount.com --quiet
```

---

## 📊 Key Features

### ✨ Improvements Over Previous Scripts
- **No hardcoded project IDs** - Dynamically uses current project
- **Proper error handling** - Exit on error with helpful messages
- **Idempotent operations** - Safe to run multiple times
- **Resume capability** - Continue interrupted deployments
- **Comprehensive help** - All scripts have `--help` flag
- **Consistent styling** - Unified color coding and output format
- **Better validation** - Checks prerequisites before running
- **Automatic cleanup** - Optional cleanup of test resources

### 🔒 Security Best Practices
- Uses dedicated service account (not default)
- Minimal IAM permissions (principle of least privilege)
- Service account scoped to required roles only

### 🎯 Production Ready
- Eventarc trigger for is_ready files (prevents duplicate processing)
- UUID folder structure (proper organization)
- Three Document AI processors (classifier + extractors)
- Structured logging with folder_uuid (traceability)
- Parallel document processing with ThreadPoolExecutor
- Proper timeout and retry configuration
- Idempotency via GCS generation tracking

---

## 📚 Related Documentation

- [../Documentation/DEPLOY_GUIDE.md](../Documentation/DEPLOY_GUIDE.md) - Complete deployment documentation
- [../Documentation/TESTING.md](../Documentation/TESTING.md) - Testing procedures

---

## 🆘 Getting Help

If you encounter issues:

1. Check script output for error messages
2. Use `--help` flag for usage information
3. Review logs: `gcloud run services logs tail apolo-procesamiento-inteligente`
4. Consult the documentation in the `Documentation/` folder