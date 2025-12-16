#!/bin/bash

# Environment Variables Update Script for Apolo Document Processing Service
# Updates Cloud Run service environment variables without full redeployment
#
# Usage:
#   ./update_env_vars.sh          # Interactive mode
#   ./update_env_vars.sh --auto   # Automatic mode
#   ./update_env_vars.sh --help   # Show help

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-south1}"
SERVICE_NAME="${SERVICE_NAME:-apolo-procesamiento-inteligente}"
AUTO_MODE=false

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
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
Environment Variables Update Script

USAGE:
    ./update_env_vars.sh [OPTIONS]

OPTIONS:
    --auto       Automatic mode (no prompts, uses defaults)
    --help       Show this help message

ENVIRONMENT VARIABLES:
    PROJECT_ID      GCP Project ID (default: current gcloud project)
    REGION          GCP Region (default: us-south1)
    SERVICE_NAME    Cloud Run service name (default: apolo-procesamiento-inteligente)

DESCRIPTION:
    Updates Cloud Run service environment variables for the Apolo Document Processing Service.
    In interactive mode, prompts for each variable. In automatic mode, uses predefined values.

CURRENT VARIABLES UPDATED:
    - GCP_PROJECT_ID
    - PROCESSOR_LOCATION
    - CLASSIFIER_PROCESSOR_NAME
    - ER_EXTRACTOR_PROCESSOR_NAME
    - ESF_EXTRACTOR_PROCESSOR_NAME
    - DLQ_TOPIC_NAME
    - MAX_CONCURRENT_DOCS
    - MAX_RETRIES

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
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

print_header "APOLO DOCUMENT PROCESSING - ENV VARS UPDATE"
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Service: $SERVICE_NAME"
echo "Mode:    $(if [[ "$AUTO_MODE" = true ]]; then echo "Automatic"; else echo "Interactive"; fi)"
echo ""

# Get current environment variables
print_info "Fetching current environment variables..."
CURRENT_VARS=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="export" \
    --quiet 2>/dev/null || echo "")

if [[ -z "$CURRENT_VARS" ]]; then
    print_error "Service $SERVICE_NAME not found in region $REGION"
    exit 1
fi

print_status "Service found"

# Define default values
DEFAULT_CLASSIFIER="apolo-preavaluo-clasificador-dev"
DEFAULT_ER_EXTRACTOR="apolo-preavaluo-er-extractor-dev"
DEFAULT_ESF_EXTRACTOR="apolo-preavaluo-esfextractor-dev"
DEFAULT_DLQ_TOPIC="apolo-preavaluo-dlq"
DEFAULT_MAX_CONCURRENT="8"
DEFAULT_MAX_RETRIES="3"

# Interactive mode
if [[ "$AUTO_MODE" = false ]]; then
    print_header "ENVIRONMENT VARIABLES CONFIGURATION"

    echo "Current/default values will be shown in brackets."
    echo "Press Enter to keep current value or type new value."
    echo ""

    # GCP_PROJECT_ID
    read -p "GCP_PROJECT_ID [$PROJECT_ID]: " GCP_PROJECT_ID
    GCP_PROJECT_ID=${GCP_PROJECT_ID:-$PROJECT_ID}

    # PROCESSOR_LOCATION
    read -p "PROCESSOR_LOCATION [$REGION]: " PROCESSOR_LOCATION
    PROCESSOR_LOCATION=${PROCESSOR_LOCATION:-$REGION}

    # CLASSIFIER_PROCESSOR_NAME
    read -p "CLASSIFIER_PROCESSOR_NAME [$DEFAULT_CLASSIFIER]: " CLASSIFIER_PROCESSOR_NAME
    CLASSIFIER_PROCESSOR_NAME=${CLASSIFIER_PROCESSOR_NAME:-$DEFAULT_CLASSIFIER}

    # ER_EXTRACTOR_PROCESSOR_NAME
    read -p "ER_EXTRACTOR_PROCESSOR_NAME [$DEFAULT_ER_EXTRACTOR]: " ER_EXTRACTOR_PROCESSOR_NAME
    ER_EXTRACTOR_PROCESSOR_NAME=${ER_EXTRACTOR_PROCESSOR_NAME:-$DEFAULT_ER_EXTRACTOR}

    # ESF_EXTRACTOR_PROCESSOR_NAME
    read -p "ESF_EXTRACTOR_PROCESSOR_NAME [$DEFAULT_ESF_EXTRACTOR]: " ESF_EXTRACTOR_PROCESSOR_NAME
    ESF_EXTRACTOR_PROCESSOR_NAME=${ESF_EXTRACTOR_PROCESSOR_NAME:-$DEFAULT_ESF_EXTRACTOR}

    # DLQ_TOPIC_NAME
    read -p "DLQ_TOPIC_NAME [$DEFAULT_DLQ_TOPIC]: " DLQ_TOPIC_NAME
    DLQ_TOPIC_NAME=${DLQ_TOPIC_NAME:-$DEFAULT_DLQ_TOPIC}

    # MAX_CONCURRENT_DOCS
    read -p "MAX_CONCURRENT_DOCS [$DEFAULT_MAX_CONCURRENT]: " MAX_CONCURRENT_DOCS
    MAX_CONCURRENT_DOCS=${MAX_CONCURRENT_DOCS:-$DEFAULT_MAX_CONCURRENT}

    # MAX_RETRIES
    read -p "MAX_RETRIES [$DEFAULT_MAX_RETRIES]: " MAX_RETRIES
    MAX_RETRIES=${MAX_RETRIES:-$DEFAULT_MAX_RETRIES}

else
    # Automatic mode - use defaults
    print_info "Using automatic configuration with default values..."
    GCP_PROJECT_ID=$PROJECT_ID
    PROCESSOR_LOCATION=$REGION
    CLASSIFIER_PROCESSOR_NAME=$DEFAULT_CLASSIFIER
    ER_EXTRACTOR_PROCESSOR_NAME=$DEFAULT_ER_EXTRACTOR
    ESF_EXTRACTOR_PROCESSOR_NAME=$DEFAULT_ESF_EXTRACTOR
    DLQ_TOPIC_NAME=$DEFAULT_DLQ_TOPIC
    MAX_CONCURRENT_DOCS=$DEFAULT_MAX_CONCURRENT
    MAX_RETRIES=$DEFAULT_MAX_RETRIES
fi

# Show configuration
print_header "CONFIGURATION SUMMARY"
echo "GCP_PROJECT_ID:              $GCP_PROJECT_ID"
echo "PROCESSOR_LOCATION:          $PROCESSOR_LOCATION"
echo "CLASSIFIER_PROCESSOR_NAME:   $CLASSIFIER_PROCESSOR_NAME"
echo "ER_EXTRACTOR_PROCESSOR_NAME: $ER_EXTRACTOR_PROCESSOR_NAME"
echo "ESF_EXTRACTOR_PROCESSOR_NAME: $ESF_EXTRACTOR_PROCESSOR_NAME"
echo "DLQ_TOPIC_NAME:              $DLQ_TOPIC_NAME"
echo "MAX_CONCURRENT_DOCS:         $MAX_CONCURRENT_DOCS"
echo "MAX_RETRIES:                 $MAX_RETRIES"
echo ""

if [[ "$AUTO_MODE" = false ]]; then
    read -p "Proceed with these values? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
fi

# Update environment variables
print_header "UPDATING ENVIRONMENT VARIABLES"

print_info "Updating Cloud Run service environment variables..."

gcloud run services update $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID" \
    --set-env-vars="PROCESSOR_LOCATION=$PROCESSOR_LOCATION" \
    --set-env-vars="CLASSIFIER_PROCESSOR_NAME=$CLASSIFIER_PROCESSOR_NAME" \
    --set-env-vars="ER_EXTRACTOR_PROCESSOR_NAME=$ER_EXTRACTOR_PROCESSOR_NAME" \
    --set-env-vars="ESF_EXTRACTOR_PROCESSOR_NAME=$ESF_EXTRACTOR_PROCESSOR_NAME" \
    --set-env-vars="DLQ_TOPIC_NAME=$DLQ_TOPIC_NAME" \
    --set-env-vars="MAX_CONCURRENT_DOCS=$MAX_CONCURRENT_DOCS" \
    --set-env-vars="MAX_RETRIES=$MAX_RETRIES" \
    --quiet

print_status "Environment variables updated successfully"

# Verify the update
print_header "VERIFICATION"

print_info "Verifying updated environment variables..."
UPDATED_VARS=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(spec.template.spec.containers[0].env[?(@.name=='CLASSIFIER_PROCESSOR_NAME')].value)" \
    --quiet 2>/dev/null || echo "")

if [[ "$UPDATED_VARS" == "$CLASSIFIER_PROCESSOR_NAME" ]]; then
    print_status "Verification successful - variables updated"
else
    print_error "Verification failed - variables may not have been updated"
fi

# Show service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(status.url)" \
    --quiet 2>/dev/null || echo "")

echo ""
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "To verify the service is working:"
echo "  ./test_uuid_processing.sh"
echo ""
echo "To view logs:"
echo "  gcloud run services logs tail ${SERVICE_NAME} --region=${REGION}"
echo ""

print_header "Update Complete"

exit 0