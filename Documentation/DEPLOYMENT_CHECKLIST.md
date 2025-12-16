# Deployment Checklist

Pre-flight checklist for deploying the Apolo document processing service to GCP.

## Pre-Deployment

### 1. GCP Project Setup
- [ ] GCP project created
- [ ] Billing enabled on project
- [ ] Project ID noted: `_________________`
- [ ] Default region set to `us-south1` (Dallas)

### 2. Local Environment
- [ ] Google Cloud SDK installed (`gcloud --version`)
- [ ] Authenticated with GCP (`gcloud auth login`)
- [ ] Docker installed (if building locally)
- [ ] Git repository cloned
- [ ] Python 3.11+ installed (for local testing)

### 3. Required APIs
Enable all required Google Cloud APIs:
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

- [ ] Cloud Run API enabled
- [ ] Cloud Build API enabled
- [ ] Cloud Storage API enabled
- [ ] Firestore API enabled
- [ ] Artifact Registry API enabled

### 4. Service Accounts
- [ ] Cloud Run service account created (or use default compute SA)
- [ ] Permissions granted:
  - [ ] `roles/storage.objectViewer` (GCS read access)
  - [ ] `roles/datastore.user` (Firestore read/write)
  - [ ] `roles/logging.logWriter` (write logs)

### 5. Infrastructure Resources

#### Cloud Storage
- [ ] Bucket created: `apolo-preavaluos-pdf-dev`
  ```bash
  gsutil mb -p apolo-dev-478018 -l us-south1 gs://apolo-preavaluos-pdf-dev
  ```
- [ ] Versioning enabled
  ```bash
  gsutil versioning set on gs://apolo-preavaluos-pdf-dev
  ```
- [ ] Lifecycle policy configured (optional)
- [ ] Test PDF uploaded for validation

#### Firestore
- [ ] Database created: `apolo-preavaluos-dev`
  ```bash
  gcloud firestore databases create \
    --database=apolo-preavaluos-dev \
    --location=us-south1 \
    --type=firestore-native
  ```
- [ ] Database location: `us-south1`
- [ ] Mode: Native (not Datastore mode)

### 6. Code Review
- [ ] Latest code pulled from main branch
- [ ] Dependencies up to date (`requirements.txt`)
- [ ] Environment variables documented
- [ ] No sensitive data in code or configs
- [ ] Dockerfile optimized and tested

### 7. Configuration Files
- [ ] `Dockerfile` present and correct
- [ ] `requirements.txt` complete
- [ ] `.dockerignore` configured
- [ ] Environment variables defined:
  - [ ] `BUCKET_NAME=apolo-preavaluos-pdf-dev`
  - [ ] `FIRESTORE_DATABASE=apolo-preavaluos-dev`
  - [ ] `PORT=8080` (default)

---

## Deployment

### Option A: Automated Script (Recommended)
- [ ] Using PowerShell script: `scripts/powershell/deploy-complete.ps1`
- [ ] Using Bash script: `scripts/bash/deploy-cloudrun.sh`
- [ ] Script execution successful
- [ ] No errors in output

### Option B: Manual Deployment
- [ ] Build container image:
  ```bash
  gcloud builds submit --tag gcr.io/PROJECT_ID/apolo-procesamiento-inteligente
  ```
- [ ] Deploy to Cloud Run:
  ```bash
  gcloud run deploy apolo-procesamiento-inteligente \
    --image gcr.io/PROJECT_ID/apolo-procesamiento-inteligente \
    --region us-south1 \
    --platform managed \
    --allow-unauthenticated \
    --memory 1Gi \
    --timeout 300s \
    --max-instances 100 \
    --set-env-vars BUCKET_NAME=apolo-preavaluos-pdf-dev,FIRESTORE_DATABASE=apolo-preavaluos-dev
  ```
- [ ] Deployment completed successfully
- [ ] Service URL obtained

### Deployment Configuration
- [ ] Region: `us-south1`
- [ ] Service name: `apolo-procesamiento-inteligente`
- [ ] Memory: 1-2 GB
- [ ] Timeout: 300s (5 minutes)
- [ ] Max instances: 100-1000 (or as needed)
- [ ] Min instances: 0 (cost optimization)
- [ ] Concurrency: 80 (default)
- [ ] CPU: Allocated only during request
- [ ] Ingress: All (or Internal if behind API Gateway)
- [ ] Authentication: 
  - [ ] Allow unauthenticated (for testing)
  - [ ] Require authentication (production)

---

## Post-Deployment Verification

### 1. Service Health Check
- [ ] Service is running
  ```bash
  gcloud run services describe apolo-procesamiento-inteligente --region us-south1
  ```
- [ ] Service URL accessible
- [ ] Status shows "Ready"

### 2. Basic Functionality Tests

#### Test 1: Health Check (if implemented)
```bash
SERVICE_URL=$(gcloud run services describe apolo-procesamiento-inteligente --region us-south1 --format='value(status.url)')
curl $SERVICE_URL/health
```
- [ ] Test 1 passed

#### Test 2: Single Document Processing
```bash
curl -X POST "${SERVICE_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "gcs_pdf_uri": "gs://apolo-preavaluos-pdf-dev/test.pdf",
    "folioId": "TEST-001",
    "fileId": "test.pdf"
  }'
```
- [ ] Test 2 passed
- [ ] Response status: 200 or 500 with proper error
- [ ] Response contains run_id
- [ ] Response contains classification
- [ ] Response contains extraction

#### Test 3: Batch Processing
```bash
curl -X POST "${SERVICE_URL}" \
  -H "Content-Type: application/json" \
  -d '{
    "folder_prefix": "test-folder/",
    "preavaluo_id": "TEST-BATCH-001",
    "max_items": 10
  }'
```
- [ ] Test 3 passed
- [ ] Batch processing works
- [ ] Multiple documents processed

#### Test 4: Idempotency Check
Run the same request twice:
```bash
# First run
curl -X POST "${SERVICE_URL}" -H "Content-Type: application/json" -d '{"gcs_pdf_uri": "gs://apolo-preavaluos-pdf-dev/test.pdf", "folioId": "IDEM-001", "fileId": "test.pdf"}'

# Second run (should use cache)
curl -X POST "${SERVICE_URL}" -H "Content-Type: application/json" -d '{"gcs_pdf_uri": "gs://apolo-preavaluos-pdf-dev/test.pdf", "folioId": "IDEM-001", "fileId": "test.pdf"}'
```
- [ ] Test 4 passed
- [ ] Second request faster
- [ ] `from_cache: true` in response

### 3. Integration Verification
- [ ] GCS bucket accessible from service
- [ ] Can read PDF files from bucket
- [ ] Firestore database accessible
- [ ] Can write to Firestore
- [ ] Can read from Firestore (cache)
- [ ] Logs appearing in Cloud Logging

### 4. Firestore Verification
Check Firestore console or use gcloud:
- [ ] Collection `runs` exists
- [ ] Documents created under runs
- [ ] Subcollection `documents` exists
- [ ] Document structure matches schema
- [ ] Timestamps populated correctly

### 5. Logging & Monitoring
- [ ] Logs visible in Cloud Logging:
  ```bash
  gcloud logging read "resource.type=cloud_run_revision" --limit 20
  ```
- [ ] Structured JSON logs present
- [ ] Progress logs showing steps
- [ ] Error logs (if any) are informative
- [ ] No sensitive data in logs

### 6. Performance Validation
- [ ] Cold start time acceptable (< 5s)
- [ ] Warm request time acceptable (< 2s)
- [ ] Document processing time reasonable
- [ ] No timeout errors
- [ ] Memory usage within limits

### 7. Error Handling
Test error scenarios:
- [ ] Invalid request (missing parameters)
- [ ] Non-existent GCS file
- [ ] Invalid PDF file
- [ ] All return proper error responses (HTTP 500)
- [ ] Error codes are specific and useful

---

## Optional: Cloud Workflows Integration

### 1. Workflow Deployment
- [ ] `workflow.yaml` file reviewed
- [ ] Workflow service account created
- [ ] Permissions granted to invoke Cloud Run
- [ ] Workflow deployed:
  ```bash
  gcloud workflows deploy apolo-document-workflow \
    --source=workflow.yaml \
    --location=us-south1
  ```

### 2. Workflow Testing
- [ ] Workflow execution successful:
  ```bash
  gcloud workflows execute apolo-document-workflow \
    --location=us-south1 \
    --data='{"folder_prefix": "TEST-001/"}'
  ```
- [ ] OIDC authentication working
- [ ] Retry logic tested (if applicable)

---

## Security Checklist

### Authentication & Authorization
- [ ] Service account permissions follow least privilege
- [ ] No overly permissive IAM roles
- [ ] Public access restricted (if needed)
- [ ] OIDC authentication configured (if using Workflows)

### Data Security
- [ ] No sensitive data in environment variables
- [ ] No API keys or passwords in code
- [ ] Encryption at rest enabled (default)
- [ ] Encryption in transit enforced (HTTPS)

### Container Security
- [ ] Running as non-root user
- [ ] Minimal base image used
- [ ] No unnecessary packages installed
- [ ] Latest security patches applied

### Network Security
- [ ] Ingress settings appropriate
- [ ] VPC connector (if needed)
- [ ] Private service access (if needed)

---

## Production Readiness

### Monitoring & Alerting
- [ ] Cloud Monitoring dashboard created (optional)
- [ ] Error rate alerts configured
- [ ] Latency alerts configured
- [ ] Budget alerts configured
- [ ] On-call rotation defined

### Backup & Recovery
- [ ] GCS versioning enabled
- [ ] Firestore backup schedule configured
- [ ] Recovery procedures documented
- [ ] RTO/RPO objectives defined

### Documentation
- [ ] Architecture documented
- [ ] API contract documented
- [ ] Deployment procedures documented
- [ ] Troubleshooting guide available
- [ ] Runbook created

### Performance & Scaling
- [ ] Load testing performed
- [ ] Scaling limits appropriate
- [ ] Cost estimates reviewed
- [ ] Performance benchmarks established

---

## Rollback Plan

If deployment fails or issues arise:

### Immediate Actions
- [ ] Rollback to previous revision:
  ```bash
  gcloud run services update-traffic apolo-procesamiento-inteligente \
    --to-revisions PREVIOUS_REVISION=100 \
    --region us-south1
  ```
- [ ] Or delete new service:
  ```bash
  gcloud run services delete apolo-procesamiento-inteligente --region us-south1
  ```

### Investigation
- [ ] Check logs for errors
- [ ] Review build logs
- [ ] Verify infrastructure resources
- [ ] Check service account permissions
- [ ] Review recent code changes

---

## Sign-Off

### Deployment Team
- [ ] Developer: _________________ Date: _______
- [ ] DevOps: _________________ Date: _______
- [ ] QA: _________________ Date: _______

### Approval
- [ ] Technical Lead: _________________ Date: _______
- [ ] Product Owner: _________________ Date: _______

### Deployment Info
- **Deployment Date**: _______
- **Deployment Time**: _______
- **Deployed By**: _______
- **Service URL**: _______
- **Version/Tag**: _______
- **Git Commit**: _______

---

## Post-Deployment Tasks

### Immediate (within 24h)
- [ ] Monitor error rates
- [ ] Monitor performance metrics
- [ ] Review logs for anomalies
- [ ] Verify user reports
- [ ] Update status page

### Short-term (within 1 week)
- [ ] Analyze usage patterns
- [ ] Review cost reports
- [ ] Optimize based on metrics
- [ ] Update documentation if needed
- [ ] Schedule retro meeting

### Long-term (within 1 month)
- [ ] Evaluate Document AI integration timeline
- [ ] Plan feature enhancements
- [ ] Review security audit results
- [ ] Optimize costs
- [ ] Update disaster recovery plan
