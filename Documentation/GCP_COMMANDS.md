# GCP Commands Reference

Essential Google Cloud Platform commands for managing the Apolo document processing service.

## Table of Contents
- [Project & Authentication](#project--authentication)
- [Cloud Run Management](#cloud-run-management)
- [Cloud Storage (GCS)](#cloud-storage-gcs)
- [Firestore](#firestore)
- [IAM & Service Accounts](#iam--service-accounts)
- [Cloud Workflows](#cloud-workflows)
- [Logging & Monitoring](#logging--monitoring)
- [Cloud Build](#cloud-build)
- [Troubleshooting](#troubleshooting)

---

## Project & Authentication

### Set Active Project
```bash
# View current project
gcloud config get-value project

# List all projects
gcloud projects list

# Set active project
gcloud config set project PROJECT_ID

# Set default region
gcloud config set run/region us-south1
```

### Authentication
```bash
# Login with user account
gcloud auth login

# Application default credentials (for local development)
gcloud auth application-default login

# Login with service account
gcloud auth activate-service-account --key-file=key.json

# Revoke credentials
gcloud auth revoke
```

### Enable Required APIs
```bash
# Enable all required APIs at once
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  firestore.googleapis.com \
  artifactregistry.googleapis.com \
  workflows.googleapis.com

# Check enabled APIs
gcloud services list --enabled
```

---

## Cloud Run Management

### Deploy Service
```bash
# Deploy from local source
gcloud run deploy apolo-procesamiento-inteligente \
  --source . \
  --region us-south1 \
  --allow-unauthenticated \
  --set-env-vars BUCKET_NAME=preavaluos-pdf,FIRESTORE_DATABASE=apolo-preavaluos-dev

# Deploy from container image
gcloud run deploy apolo-procesamiento-inteligente \
  --image gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:latest \
  --region us-south1 \
  --platform managed \
  --memory 1Gi \
  --timeout 300s \
  --max-instances 100 \
  --set-env-vars BUCKET_NAME=preavaluos-pdf,FIRESTORE_DATABASE=apolo-preavaluos-dev
```

### Service Information
```bash
# List all Cloud Run services
gcloud run services list --region us-south1

# Describe specific service
gcloud run services describe apolo-procesamiento-inteligente --region us-south1

# Get service URL
gcloud run services describe apolo-procesamiento-inteligente \
  --region us-south1 \
  --format='value(status.url)'
```

### Service Configuration
```bash
# Update environment variables
gcloud run services update apolo-procesamiento-inteligente \
  --region us-south1 \
  --set-env-vars KEY=VALUE

# Update memory
gcloud run services update apolo-procesamiento-inteligente \
  --region us-south1 \
  --memory 2Gi

# Update timeout
gcloud run services update apolo-procesamiento-inteligente \
  --region us-south1 \
  --timeout 300s

# Update max instances
gcloud run services update apolo-procesamiento-inteligente \
  --region us-south1 \
  --max-instances 1000

# Update to require authentication
gcloud run services update apolo-procesamiento-inteligente \
  --region us-south1 \
  --no-allow-unauthenticated
```

### Service Management
```bash
# Delete service
gcloud run services delete apolo-procesamiento-inteligente --region us-south1

# List revisions
gcloud run revisions list --region us-south1 --service apolo-procesamiento-inteligente

# Rollback to previous revision
gcloud run services update-traffic apolo-procesamiento-inteligente \
  --region us-south1 \
  --to-revisions REVISION_NAME=100
```

### Test Service
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe apolo-procesamiento-inteligente \
  --region us-south1 \
  --format='value(status.url)')

# Test with curl (unauthenticated)
curl -X POST "${SERVICE_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "gcs_pdf_uri": "gs://preavaluos-pdf/test.pdf",
    "folioId": "TEST-001",
    "fileId": "test.pdf"
  }'

# Test with authentication
curl -X POST "${SERVICE_URL}" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"folder_prefix": "PRE-2025-001/"}'
```

---

## Cloud Storage (GCS)

### Bucket Management
```bash
# Create bucket
gsutil mb -p PROJECT_ID -l us-south1 gs://preavaluos-pdf

# List buckets
gsutil ls

# Bucket details
gsutil ls -L -b gs://preavaluos-pdf

# Delete bucket (careful!)
gsutil rm -r gs://preavaluos-pdf
```

### Bucket Configuration
```bash
# Enable versioning
gsutil versioning set on gs://preavaluos-pdf

# Set lifecycle policy
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"age": 90}
    }]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://preavaluos-pdf

# Set CORS policy
gsutil cors set cors.json gs://preavaluos-pdf

# Make bucket public (not recommended)
gsutil iam ch allUsers:objectViewer gs://preavaluos-pdf
```

### Object Operations
```bash
# Upload file
gsutil cp local-file.pdf gs://preavaluos-pdf/folder/file.pdf

# Upload directory
gsutil cp -r local-directory/ gs://preavaluos-pdf/folder/

# List objects
gsutil ls gs://preavaluos-pdf/
gsutil ls -r gs://preavaluos-pdf/  # Recursive

# Download file
gsutil cp gs://preavaluos-pdf/file.pdf local-file.pdf

# Delete object
gsutil rm gs://preavaluos-pdf/file.pdf

# Delete folder
gsutil rm -r gs://preavaluos-pdf/folder/

# Copy between buckets
gsutil cp gs://source-bucket/file.pdf gs://dest-bucket/file.pdf

# Move/rename object
gsutil mv gs://bucket/old-name.pdf gs://bucket/new-name.pdf
```

### Object Metadata
```bash
# View object metadata
gsutil stat gs://preavaluos-pdf/file.pdf

# Set custom metadata
gsutil setmeta -h "x-goog-meta-key:value" gs://preavaluos-pdf/file.pdf

# Make object public
gsutil acl ch -u AllUsers:R gs://preavaluos-pdf/file.pdf
```

---

## Firestore

### Database Management
```bash
# Create database (Native mode)
gcloud firestore databases create \
  --database=apolo-preavaluos-dev \
  --location=us-south1 \
  --type=firestore-native

# List databases
gcloud firestore databases list

# Describe database
gcloud firestore databases describe apolo-preavaluos-dev
```

### Data Operations
```bash
# Export data (requires GCS bucket)
gcloud firestore export gs://backup-bucket/firestore-backup \
  --database=apolo-preavaluos-dev

# Import data
gcloud firestore import gs://backup-bucket/firestore-backup \
  --database=apolo-preavaluos-dev

# List collections (requires gcloud alpha)
gcloud alpha firestore collections list \
  --database=apolo-preavaluos-dev
```

### Indexes
```bash
# Create index
gcloud firestore indexes composite create \
  --database=apolo-preavaluos-dev \
  --collection-group=documents \
  --field-config field-path=status,order=ascending \
  --field-config field-path=createdAt,order=descending

# List indexes
gcloud firestore indexes composite list \
  --database=apolo-preavaluos-dev

# Delete index
gcloud firestore indexes composite delete INDEX_ID \
  --database=apolo-preavaluos-dev
```

---

## IAM & Service Accounts

### Service Account Management
```bash
# Create service account
gcloud iam service-accounts create apolo-processor-sa \
  --display-name="Apolo Document Processor Service Account"

# List service accounts
gcloud iam service-accounts list

# Delete service account
gcloud iam service-accounts delete apolo-processor-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Grant Permissions
```bash
# Grant Cloud Run access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/run.invoker"

# Grant Storage access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/storage.objectViewer"

# Grant Firestore access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/datastore.user"

# Grant multiple roles at once
for role in run.invoker storage.objectViewer datastore.user; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:SA_EMAIL" \
    --role="roles/${role}"
done
```

### Service Account Keys
```bash
# Create key file
gcloud iam service-accounts keys create key.json \
  --iam-account=SA_EMAIL

# List keys
gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL

# Delete key
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL
```

---

## Cloud Workflows

### Deploy Workflow
```bash
# Deploy from YAML file
gcloud workflows deploy apolo-document-workflow \
  --source=workflow.yaml \
  --location=us-south1 \
  --service-account=workflow-sa@PROJECT_ID.iam.gserviceaccount.com

# List workflows
gcloud workflows list --location=us-south1

# Describe workflow
gcloud workflows describe apolo-document-workflow --location=us-south1
```

### Execute Workflow
```bash
# Execute workflow
gcloud workflows execute apolo-document-workflow \
  --location=us-south1 \
  --data='{"folder_prefix": "PRE-2025-001/", "preavaluo_id": "PRE-2025-001"}'

# List executions
gcloud workflows executions list apolo-document-workflow --location=us-south1

# Describe execution
gcloud workflows executions describe EXECUTION_ID \
  --workflow=apolo-document-workflow \
  --location=us-south1
```

### Workflow Management
```bash
# Update workflow
gcloud workflows deploy apolo-document-workflow \
  --source=workflow.yaml \
  --location=us-south1

# Delete workflow
gcloud workflows delete apolo-document-workflow --location=us-south1
```

---

## Logging & Monitoring

### View Logs
```bash
# Cloud Run service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=apolo-procesamiento-inteligente" \
  --limit 50 \
  --format json

# Logs from last hour
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=apolo-procesamiento-inteligente" \
  --freshness=1h

# Filter by severity
gcloud logging read "resource.type=cloud_run_revision AND severity=ERROR" \
  --limit 20

# Stream logs in real-time
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=apolo-procesamiento-inteligente"

# Search for specific text
gcloud logging read "resource.type=cloud_run_revision AND textPayload:\"error\"" \
  --limit 10
```

### Metrics
```bash
# List available metrics
gcloud monitoring metrics-descriptors list \
  --filter="metric.type:run.googleapis.com"

# Get request count
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"' \
  --format=json
```

---

## Cloud Build

### Build Container
```bash
# Build and push to Container Registry
gcloud builds submit \
  --tag gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:latest

# Build with custom Dockerfile
gcloud builds submit \
  --tag gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:v1.0 \
  --dockerfile Dockerfile

# Build with Cloud Build config
gcloud builds submit --config cloudbuild.yaml
```

### Build History
```bash
# List builds
gcloud builds list --limit=10

# Describe specific build
gcloud builds describe BUILD_ID

# View build logs
gcloud builds log BUILD_ID
```

### Container Images
```bash
# List images in Container Registry
gcloud container images list --repository=gcr.io/PROJECT_ID

# List tags for an image
gcloud container images list-tags gcr.io/PROJECT_ID/apolo-procesamiento-inteligente

# Delete image
gcloud container images delete gcr.io/PROJECT_ID/apolo-procesamiento-inteligente:tag

# Delete untagged images
gcloud container images list-tags gcr.io/PROJECT_ID/apolo-procesamiento-inteligente \
  --filter='-tags:*' \
  --format='get(digest)' \
  --limit=10 | \
  xargs -I {} gcloud container images delete gcr.io/PROJECT_ID/apolo-procesamiento-inteligente@{} --quiet
```

---

## Troubleshooting

### Check Service Status
```bash
# Get service details
gcloud run services describe apolo-procesamiento-inteligente \
  --region us-south1 \
  --format=yaml

# Check latest revision
gcloud run revisions list \
  --region us-south1 \
  --service apolo-procesamiento-inteligente \
  --limit=1

# Get error logs
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
  --limit=50 \
  --format=json
```

### Test Connectivity
```bash
# Test if service is reachable
SERVICE_URL=$(gcloud run services describe apolo-procesamiento-inteligente \
  --region us-south1 \
  --format='value(status.url)')

curl -I $SERVICE_URL

# Test with verbose output
curl -v $SERVICE_URL
```

### Check Permissions
```bash
# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL"

# Test Cloud Run invocation permission
gcloud run services get-iam-policy apolo-procesamiento-inteligente \
  --region us-south1
```

### Quota & Limits
```bash
# Check quota usage
gcloud compute project-info describe --project=PROJECT_ID

# List quotas
gcloud compute regions describe us-south1 --project=PROJECT_ID
```

### Debug Build Issues
```bash
# View recent build logs
gcloud builds list --limit=1 --format=json | jq '.[0].id' | \
  xargs -I {} gcloud builds log {}

# Check build trigger
gcloud builds triggers list

# Manually trigger build
gcloud builds triggers run TRIGGER_NAME
```

---

## Quick Reference Card

### Essential Commands
```bash
# Set project
gcloud config set project PROJECT_ID

# Deploy service
gcloud run deploy apolo-procesamiento-inteligente --source . --region us-south1

# View logs
gcloud logging tail "resource.type=cloud_run_revision"

# Test service
curl -X POST $SERVICE_URL -H "Content-Type: application/json" -d '{}'

# List buckets
gsutil ls

# Upload to GCS
gsutil cp file.pdf gs://preavaluos-pdf/

# Export Firestore
gcloud firestore export gs://backup-bucket/backup
```

### Environment Variables
```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-south1"
export SERVICE_NAME="apolo-procesamiento-inteligente"
export BUCKET_NAME="preavaluos-pdf"
export FIRESTORE_DATABASE="apolo-preavaluos-dev"
export SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')
```
