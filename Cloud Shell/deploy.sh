#!/bin/bash

# Apolo Document Processing Service - Unified Deployment Script
# This script sets up all GCP infrastructure and deploys the service
# Run in Google Cloud Shell
#
# Usage:
#   ./deploy.sh              # Full deployment from scratch
#   ./deploy.sh --resume     # Resume interrupted deployment
#   ./deploy.sh --help       # Show help

set -e  # Exit on error

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration variables
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-south1}"
SERVICE_NAME="${SERVICE_NAME:-apolo-procesamiento-inteligente}"
BUCKET_NAME="${BUCKET_NAME:-apolo-preavaluos-pdf-dev}"
DLQ_TOPIC_NAME="${DLQ_TOPIC_NAME:-apolo-preavaluo-dlq}"
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-apolo-procesamiento-sa}"
TRIGGER_NAME="${TRIGGER_NAME:-apolo-procesamiento-trigger}"

# Resume flag
RESUME_MODE=false
SKIP_TESTS=false

# Helper functions
print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

show_help() {
    cat << EOF
Apolo Document Processing Service - Deployment Script

USAGE:
    ./deploy.sh [OPTIONS]

OPTIONS:
    --resume     Resume interrupted deployment
    --skip-tests Skip automated tests after deployment
    --help       Show this help message

ENVIRONMENT VARIABLES:
    PROJECT_ID          GCP Project ID (default: current gcloud project)
    REGION              GCP Region (default: us-south1)
    SERVICE_NAME        Cloud Run service name (default: apolo-procesamiento-inteligente)
    BUCKET_NAME         GCS bucket name (default: apolo-preavaluos-pdf-dev)
    DLQ_TOPIC_NAME      Pub/Sub DLQ topic (default: apolo-preavaluo-dlq)

DESCRIPTION:
    This script deploys the Apolo Document Processing Service with:
    - Cloud Run service with Eventarc trigger
    - Cloud Storage bucket
    - Service account with proper IAM roles
    - Pub/Sub DLQ topic
    - Automated testing

EXAMPLES:
    ./deploy.sh                          # Full deployment
    ./deploy.sh --resume                 # Resume deployment
    PROJECT_ID=my-project ./deploy.sh    # Specific project

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --resume)
            RESUME_MODE=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate prerequisites
if [[ -z "$PROJECT_ID" ]]; then
    print_error "PROJECT_ID not set. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
    print_error "Not authenticated with gcloud. Run: gcloud auth login"
    exit 1
fi

print_header "APOLO DOCUMENT PROCESSING SERVICE DEPLOYMENT"
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Service: $SERVICE_NAME"
echo "Bucket:  $BUCKET_NAME"
echo ""

# Step 1: Enable required APIs
if [[ "$RESUME_MODE" = false ]]; then
    print_header "Step 1: Enabling GCP APIs"

    print_info "Enabling required APIs..."
    gcloud services enable cloudbuild.googleapis.com \
        run.googleapis.com \
        eventarc.googleapis.com \
        storage.googleapis.com \
        firestore.googleapis.com \
        documentai.googleapis.com \
        pubsub.googleapis.com \
        --project=$PROJECT_ID \
        --quiet

    print_status "GCP APIs enabled"
fi

# Step 2: Create service account
print_header "Step 2: Creating Service Account"

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &>/dev/null; then
    print_info "Service account already exists: $SA_EMAIL"
else
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --description="Service account for Apolo Document Processing Service" \
        --display-name="Apolo Processing SA" \
        --project=$PROJECT_ID \
        --quiet

    print_status "Created service account: $SA_EMAIL"
fi

# Grant roles
print_info "Granting IAM roles..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.objectViewer" \
    --condition=None \
    --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/datastore.user" \
    --condition=None \
    --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/documentai.apiUser" \
    --condition=None \
    --quiet

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/pubsub.publisher" \
    --condition=None \
    --quiet

print_status "IAM roles configured"

# Step 3: Create Cloud Storage bucket
if [[ "$RESUME_MODE" = false ]]; then
    print_header "Step 3: Creating Cloud Storage Bucket"

    if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
        print_info "Bucket already exists: $BUCKET_NAME"
    else
        gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
        print_status "Created bucket: gs://$BUCKET_NAME"
    fi

    # Enable versioning
    gsutil versioning set on gs://$BUCKET_NAME
    print_status "Versioning enabled on bucket"
fi

# Step 4: Create Pub/Sub DLQ topic
if [[ "$RESUME_MODE" = false ]]; then
    print_header "Step 4: Creating Pub/Sub DLQ Topic"

    if gcloud pubsub topics describe $DLQ_TOPIC_NAME --project=$PROJECT_ID &>/dev/null; then
        print_info "DLQ topic already exists: $DLQ_TOPIC_NAME"
    else
        gcloud pubsub topics create $DLQ_TOPIC_NAME \
            --project=$PROJECT_ID \
            --quiet
        print_status "Created DLQ topic: $DLQ_TOPIC_NAME"
    fi
fi

# Step 5: Deploy Cloud Run service
print_header "Step 5: Deploying Cloud Run Service"

print_info "Building and deploying $SERVICE_NAME..."
print_info "This may take 3-5 minutes..."

# Navigate to parent directory for build context
cd ..

gcloud run deploy $SERVICE_NAME \
    --source . \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --service-account=$SA_EMAIL \
    --memory=1Gi \
    --cpu=1 \
    --timeout=300 \
    --max-instances=10 \
    --set-env-vars="GCP_PROJECT_ID=$PROJECT_ID" \
    --set-env-vars="PROCESSOR_LOCATION=$REGION" \
    --set-env-vars="CLASSIFIER_PROCESSOR_NAME=apolo-preavaluo-clasificador-dev" \
    --set-env-vars="ER_EXTRACTOR_PROCESSOR_NAME=apolo-preavaluo-er-extractor-dev" \
    --set-env-vars="ESF_EXTRACTOR_PROCESSOR_NAME=apolo-preavaluo-esfextractor-dev" \
    --set-env-vars="DLQ_TOPIC_NAME=$DLQ_TOPIC_NAME" \
    --set-env-vars="MAX_CONCURRENT_DOCS=8" \
    --set-env-vars="MAX_RETRIES=3" \
    --quiet

SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")
print_status "Service deployed: $SERVICE_URL"

# Step 6: Create Eventarc trigger
print_header "Step 6: Creating Eventarc Trigger"

if gcloud eventarc triggers describe $TRIGGER_NAME --location=$REGION --project=$PROJECT_ID &>/dev/null; then
    print_info "Eventarc trigger already exists: $TRIGGER_NAME"
else
    gcloud eventarc triggers create $TRIGGER_NAME \
        --location=$REGION \
        --destination-run-service=$SERVICE_NAME \
        --destination-run-region=$REGION \
        --event-filters="type=google.cloud.storage.object.v1.finalized" \
        --event-filters="bucket=$BUCKET_NAME" \
        --service-account=$SA_EMAIL \
        --project=$PROJECT_ID \
        --quiet

    print_status "Created Eventarc trigger: $TRIGGER_NAME"
fi

# Step 7: Run tests (if not skipped)
if [[ "$SKIP_TESTS" = false ]]; then
    print_header "Step 7: Running Tests"

    cd "Cloud Shell"

    print_info "Running test script..."
    if ./test_uuid_processing.sh --cleanup; then
        print_status "Tests passed successfully"
    else
        print_error "Tests failed - check output above"
        exit 1
    fi
else
    print_info "Tests skipped (--skip-tests flag used)"
fi

# Final summary
print_header "DEPLOYMENT COMPLETE"

echo -e "${GREEN}✓ Apolo Document Processing Service deployed successfully!${NC}"
echo ""
echo "Resources Created:"
echo "  • Service Account:      $SA_EMAIL"
echo "  • Cloud Storage Bucket: gs://$BUCKET_NAME"
echo "  • Cloud Run Service:    $SERVICE_NAME"
echo "  • Service URL:          $SERVICE_URL"
echo "  • Eventarc Trigger:     $TRIGGER_NAME"
echo "  • DLQ Topic:           $DLQ_TOPIC_NAME"
echo ""

print_header "USAGE INSTRUCTIONS"

echo "Upload files to UUID folders:"
echo "  UUID=\$(uuidgen | tr '[:upper:]' '[:lower:]')"
echo "  gsutil cp your-file.pdf gs://$BUCKET_NAME/\$UUID/"
echo "  echo \"\" | gsutil cp - gs://$BUCKET_NAME/\$UUID/is_ready"
echo ""
echo "Check output:"
echo "  gsutil ls gs://$BUCKET_NAME/\$UUID/"
echo ""
echo "View logs:"
echo "  gcloud run services logs tail $SERVICE_NAME --region=$REGION"
echo ""
echo "View logs for specific UUID:"
echo "  gcloud logging read \"jsonPayload.folder_uuid=\\\"\$UUID\\\"\" --limit=20"
echo ""
echo "Run additional tests:"
echo "  cd Cloud\\ Shell && ./test_uuid_processing.sh"
echo ""

print_header "CLEANUP COMMANDS"

echo "To remove all resources when done:"
echo "  gcloud run services delete $SERVICE_NAME --region=$REGION --quiet"
echo "  gsutil -m rm -r gs://$BUCKET_NAME"
echo "  gcloud eventarc triggers delete $TRIGGER_NAME --location=$REGION --quiet"
echo "  gcloud pubsub topics delete $DLQ_TOPIC_NAME --project=$PROJECT_ID --quiet"
echo "  gcloud iam service-accounts delete $SA_EMAIL --quiet"
echo ""

print_header "Deployment Complete!"

exit 0