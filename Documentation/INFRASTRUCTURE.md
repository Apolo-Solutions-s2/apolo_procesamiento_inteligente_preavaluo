# Infrastructure Summary

Complete overview of the Apolo document processing infrastructure on Google Cloud Platform.

## Infrastructure Components

### Compute Layer

#### Cloud Run Service
- **Service Name**: `apolo-procesamiento-inteligente`
- **Type**: Fully managed serverless container platform (2nd generation)
- **Region**: us-south1 (Dallas, Texas)
- **Runtime**: Python 3.11
- **Container**: Custom Docker image based on python:3.11-slim
- **Auto-scaling**: 0-1000 instances (configurable per environment)
- **Memory**: 512MB - 2GB (environment dependent)
- **CPU**: Allocated during request only
- **Timeout**: 300 seconds (5 minutes)
- **Concurrency**: 80 requests per instance
- **Port**: 8080 (standard Cloud Run)

**Cost Model**: Pay only during request processing (scale to zero)

---

### Storage Layer

#### Google Cloud Storage (GCS)
- **Bucket Name**: `preavaluos-pdf`
- **Location**: us-south1 (region)
- **Storage Class**: Standard
- **Versioning**: Enabled (90-day retention)
- **Lifecycle Policy**: Delete old versions after 90 days
- **Access**: Private (service account based)
- **Purpose**: Store source PDF documents for processing

**Cost Model**: ~$0.02/GB/month + operations charges

---

### Database Layer

#### Cloud Firestore (Native Mode)
- **Database Name**: `apolo-preavaluos-dev` (environment suffix)
- **Type**: Native mode (not Datastore)
- **Location**: us-south1
- **Collections**:
  - `runs/` - Processing batch metadata
    - `documents/` - Individual document results (subcollection)
- **Purpose**: 
  - Result persistence
  - Idempotency caching
  - Audit trail
  - Run tracking

**Cost Model**: 
- Reads: $0.06 per 100K
- Writes: $0.18 per 100K
- Storage: $0.18/GB/month

---

### Orchestration Layer (Optional)

#### Cloud Workflows
- **Workflow Name**: `apolo-document-workflow`
- **Location**: us-south1
- **Purpose**: 
  - Complex multi-step orchestration
  - Automatic retries with exponential backoff
  - OIDC authentication to Cloud Run
  - Execution correlation tracking
- **Status**: Prepared but not required (optional enhancement)

**Cost Model**: $0.01 per 1000 internal steps

---

## Security Architecture

### Service Accounts

#### Cloud Run Service Account
- **Email**: `{service-name}-sa@{project}.iam.gserviceaccount.com`
- **Purpose**: Execute Cloud Run service with minimal permissions
- **Permissions**:
  - `roles/storage.objectViewer` - Read PDFs from GCS
  - `roles/datastore.user` - Read/Write Firestore
  - `roles/logging.logWriter` - Write structured logs

#### Workflow Service Account (Optional)
- **Email**: `workflow-sa@{project}.iam.gserviceaccount.com`
- **Purpose**: Execute Cloud Workflows
- **Permissions**:
  - `roles/run.invoker` - Invoke Cloud Run service
  - `roles/logging.logWriter` - Write execution logs

### Authentication Methods

| Integration Method | Authentication | Use Case |
|--------------------|----------------|----------|
| Direct HTTP | Unauthenticated or API Key | Development/Testing |
| Cloud Workflows | OIDC Token | Production Orchestration |
| Internal Services | Service Account Token | Microservice Integration |
| External API | Cloud Endpoints + API Key | Public API (future) |

### Network Security
- **Ingress**: All traffic (configurable to internal-only)
- **Egress**: Unrestricted (access to GCP services)
- **VPC**: Optional VPC connector for private resources
- **HTTPS**: Enforced by Cloud Run (TLS 1.2+)

---

## Deployment Architecture

### Environment Strategy

#### Development
- **Purpose**: Feature development and testing
- **Configuration**:
  - Min instances: 0 (cost optimization)
  - Max instances: 10
  - Memory: 512MB
  - Public access: Yes
  - Monitoring: Basic
- **Firestore DB**: `apolo-preavaluos-dev`
- **Cost**: ~$10-30/month

#### QA/Staging
- **Purpose**: Integration testing and validation
- **Configuration**:
  - Min instances: 0
  - Max instances: 50
  - Memory: 1GB
  - Public access: No (internal only)
  - Monitoring: Standard
- **Firestore DB**: `apolo-preavaluos-qa`
- **Cost**: ~$20-50/month

#### Production
- **Purpose**: Live traffic handling
- **Configuration**:
  - Min instances: 1 (always warm, no cold starts)
  - Max instances: 1000
  - Memory: 2GB
  - Public access: No (authenticated only)
  - Monitoring: Full alerting
- **Firestore DB**: `apolo-preavaluos-prod`
- **Cost**: ~$100-500/month (traffic dependent)

---

## Deployment Methods

### Method 1: Automated Scripts (Recommended)
**Location**: `scripts/`

**PowerShell** (Windows):
```powershell
.\scripts\powershell\deploy-complete.ps1
```

**Bash** (Linux/Mac/Cloud Shell):
```bash
./scripts/bash/deploy-cloudrun.sh
```

**Advantages**:
- Complete automation
- Environment setup included
- Testing included
- Error handling
- Progress reporting

### Method 2: Terraform (IaC)
**Location**: `infrastructure/terraform/`

```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file="env/dev.tfvars"
```

**Advantages**:
- Infrastructure as Code
- Version controlled
- State management
- Multi-environment support
- Repeatable deployments

### Method 3: Manual gcloud
**Documentation**: `Documentation/GCP_COMMANDS.md`

```bash
gcloud run deploy apolo-procesamiento-inteligente \
  --source . \
  --region us-south1
```

**Advantages**:
- Full control
- Learning/debugging
- One-off deployments

---

## Monitoring & Observability

### Logging Strategy
- **Type**: Structured JSON logs
- **Destination**: Cloud Logging
- **Retention**: 30 days (default)
- **Fields**:
  - `event_type` - Type of event (progress, error, etc.)
  - `ts_utc` - ISO 8601 timestamp
  - `run_id` - Correlation ID
  - `step` - Processing stage
  - `percent` - Progress percentage

### Log Queries
```
# View recent logs
resource.type="cloud_run_revision"
resource.labels.service_name="apolo-procesamiento-inteligente"

# Error logs only
resource.type="cloud_run_revision" AND severity>=ERROR

# Specific run
resource.type="cloud_run_revision" AND jsonPayload.run_id="xyz123"
```

### Metrics (Cloud Monitoring)

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| Request Count | Total requests | - |
| Request Latency | P50, P95, P99 | P99 > 10s |
| Error Rate | 5xx / total | > 5% |
| Instance Count | Active instances | > 900 (capacity warning) |
| Memory Usage | Container memory | > 90% |
| CPU Usage | vCPU utilization | > 80% |

### Alerting (Production Only)
- Error rate > 5% for 5 minutes
- P99 latency > 10 seconds
- Service unavailable > 1 minute
- Budget threshold (80% and 100%)

---

## Data Flow

### Document Processing Pipeline

```
1. Client Request
   ├─ HTTP POST to Cloud Run
   └─ JSON payload with document info

2. Request Validation
   ├─ Check required parameters
   ├─ Normalize inputs
   └─ Generate run_id for correlation

3. Idempotency Check
   ├─ Query Firestore: runs/{runId}/documents/{docId}
   ├─ If exists & completed → return cached
   └─ If not exists → acquire processing lease

4. PDF Validation (Early Failure Detection)
   ├─ Read first 5 bytes from GCS
   ├─ Verify PDF magic number (%PDF-)
   └─ Fail fast if invalid (prevent AI costs)

5. Document AI Classification (Currently Simulated)
   ├─ Identify document type
   ├─ Return confidence score
   └─ Types: ESTADO_RESULTADOS, ESTADO_SITUACION_FINANCIERA, ESTADO_FLUJOS_EFECTIVO

6. Document AI Extraction (Currently Simulated)
   ├─ Extract structured fields by type
   ├─ Parse financial line items
   └─ Generate metadata

7. Result Persistence
   ├─ Save to Firestore: runs/{runId}/documents/{docId}
   ├─ Update run-level counters
   └─ Release processing lease

8. Response Generation
   ├─ Aggregate all document results
   ├─ Calculate success/failure counts
   └─ Return JSON with complete data
```

### Batch Processing Flow
- Discover documents in GCS folder
- Process each document independently
- Aggregate results
- Partial failure support (some succeed, some fail)

---

## Backup & Disaster Recovery

### Data Backup Strategy

#### GCS Bucket
- **Versioning**: Enabled (90 days)
- **Backup**: Automatic versioning
- **Restore**: Point-in-time recovery via versions
- **Cross-region**: Not configured (single region)

#### Firestore
- **Backup**: Daily automated backups (GCP managed)
- **Retention**: 7 days (can be extended)
- **Export**: Manual export to GCS
- **Restore**: Point-in-time restore or import from export

#### Code & Configuration
- **Repository**: GitHub (apolo_procesamiento_inteligente_preavaluo)
- **Branching**: main (production), develop (staging)
- **Tags**: Semantic versioning (v1.0.0, v1.1.0)
- **IaC**: Terraform state in GCS with versioning

### Recovery Procedures

#### Service Failure
1. Auto-restart by Cloud Run (automatic)
2. Health checks initiate restart
3. RTO: < 1 minute

#### Region Outage
1. Manual deployment to backup region
2. Update DNS/traffic routing
3. RTO: 15-30 minutes

#### Data Corruption
1. Stop service to prevent further corruption
2. Restore Firestore from backup
3. Restore GCS bucket from versions
4. Validate data integrity
5. Resume service
6. RTO: 1-2 hours

#### Code Rollback
1. Identify previous working revision
2. Deploy previous container image
3. Or rollback traffic to previous revision
4. RTO: < 5 minutes

---

## Cost Breakdown

### Estimated Monthly Costs (Development)

| Service | Usage | Cost |
|---------|-------|------|
| Cloud Run | 10K requests, 100ms avg | $2 |
| Cloud Storage | 10GB storage + ops | $1 |
| Firestore | 50K reads, 10K writes | $0.50 |
| Cloud Build | 10 builds/month | $1 |
| Cloud Logging | 5GB logs | $1 |
| **Total** | | **~$5.50** |

### Estimated Monthly Costs (Production - Light Traffic)

| Service | Usage | Cost |
|---------|-------|------|
| Cloud Run | 100K requests, 1 warm instance | $25 |
| Cloud Storage | 100GB storage + ops | $4 |
| Firestore | 500K reads, 100K writes | $4 |
| Cloud Build | 20 builds/month | $2 |
| Cloud Logging | 20GB logs | $4 |
| Cloud Monitoring | Metrics + alerts | $5 |
| **Total** | | **~$44** |

### Cost Optimization Strategies
1. **Scale to zero** in dev/qa (min_instances=0)
2. **Idempotency** prevents duplicate processing
3. **Early PDF validation** fails before expensive AI calls
4. **Efficient container** size reduces cold start costs
5. **Result caching** in Firestore reduces reprocessing
6. **Lifecycle policies** on GCS delete old versions

---

## Performance Characteristics

### Latency
- **Cold start**: 2-3 seconds (first request to idle instance)
- **Warm request**: 100-500ms (request to warm instance)
- **Document processing**: 1-2 seconds per document (simulated AI)
- **Batch processing**: Parallel, scales with instance count

### Throughput
- **Single instance**: ~80 concurrent requests
- **Max throughput**: 80K concurrent requests (1000 instances × 80)
- **Sustainable**: Depends on processing time and instance limits

### Scalability
- **Vertical**: Up to 8GB memory, 4 vCPU per instance
- **Horizontal**: Up to 1000 instances (configurable)
- **Storage**: Unlimited (GCS)
- **Database**: Unlimited (Firestore auto-scales)

---

## Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Runtime** | Python | 3.11 | Application code |
| **Framework** | Flask | 3.x | HTTP server |
| **Function Framework** | functions-framework | 3.x | Cloud Function compatibility |
| **Cloud Platform** | Google Cloud Platform | - | Infrastructure provider |
| **Compute** | Cloud Run | Gen 2 | Serverless containers |
| **Storage** | Cloud Storage | - | Object storage |
| **Database** | Firestore | Native | NoSQL database |
| **Container** | Docker | 20+ | Containerization |
| **Base Image** | python:3.11-slim | - | Minimal Python image |
| **Orchestration** | Cloud Workflows | - | Optional workflow engine |
| **IaC** | Terraform | 1.5+ | Infrastructure as Code |
| **CI/CD** | Cloud Build | - | Build and deploy |
| **Monitoring** | Cloud Logging/Monitoring | - | Observability |

---

## Integration Points

### Input Integrations
1. **Direct HTTP** - REST API clients
2. **Cloud Workflows** - Orchestration layer
3. **Cloud Scheduler** - Scheduled batch processing
4. **Pub/Sub** (future) - Event-driven processing
5. **API Gateway** (future) - Public API exposure

### Output Integrations
1. **Firestore** - Primary data store
2. **Cloud Logging** - Structured logs
3. **Cloud Monitoring** - Metrics and alerts
4. **BigQuery** (future) - Analytics
5. **Pub/Sub** (future) - Event notifications

### External Service Dependencies
1. **Document AI** (future) - ML classification and extraction
2. **Secret Manager** (optional) - Secure config storage
3. **Cloud KMS** (optional) - Encryption key management

---

## Maintenance Windows

### Regular Maintenance
- **GCP Maintenance**: Transparent, handled by GCP
- **Dependency Updates**: Monthly (Python packages)
- **Security Patches**: As needed (critical within 24h)

### Planned Maintenance
- **Major Updates**: Scheduled during low traffic
- **Database Migrations**: Scheduled, zero-downtime preferred
- **Infrastructure Changes**: Tested in dev/qa first

---

## Compliance & Governance

### Data Residency
- **Region**: us-south1 (United States)
- **Data at Rest**: Stays in configured region
- **Data in Transit**: May cross regions for GCP APIs

### Access Control
- **Principle**: Least privilege
- **Authentication**: Service account based
- **Authorization**: IAM roles
- **Audit**: Cloud Audit Logs enabled

### Encryption
- **At Rest**: Default Google encryption
- **In Transit**: TLS 1.2+ enforced
- **Keys**: Google-managed (option for CMEK)

---

## Support & Escalation

### Tier 1: Self-Service
- Documentation in `Documentation/`
- GCP command reference
- Troubleshooting guides

### Tier 2: Team Support
- DevOps team
- Development team
- Architecture review

### Tier 3: GCP Support
- GCP Support console
- Support cases
- Technical Account Manager (if applicable)

---

## Version Information

| Component | Version | Last Updated |
|-----------|---------|--------------|
| Infrastructure | 1.0.0 | 2025-12-04 |
| Python Runtime | 3.11 | 2025-12-04 |
| Terraform Config | 1.0.0 | 2025-12-04 |
| Documentation | 1.0.0 | 2025-12-04 |

---

**Document Owner**: DevOps Team  
**Last Reviewed**: December 2025  
**Next Review**: March 2026
