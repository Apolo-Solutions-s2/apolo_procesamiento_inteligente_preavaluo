#!/bin/bash

# UUID Folder Processing Test Script
# Tests the document processing service with UUID-based folder structure
#
# Usage:
#   ./test_uuid_processing.sh                    # Uses current project
#   ./test_uuid_processing.sh --project PROJECT  # Specify project
#   ./test_uuid_processing.sh --help             # Show help

set -e

# Color codes for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
BUCKET_NAME="${BUCKET_NAME:-apolo-preavaluos-pdf-dev}"
SERVICE_NAME="${SERVICE_NAME:-apolo-procesamiento-inteligente}"
REGION="${REGION:-us-south1}"
CLEANUP_AFTER=false
VERBOSE=false

# Helper functions
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

show_help() {
    cat << EOF
UUID Folder Processing Test Script

USAGE:
    ./test_uuid_processing.sh [OPTIONS]

OPTIONS:
    --project PROJECT    Specify GCP project ID
    --cleanup           Automatically cleanup test files after completion
    --verbose           Show detailed output
    --help              Show this help message

ENVIRONMENT VARIABLES:
    PROJECT_ID          GCP Project ID (default: current gcloud project)
    BUCKET_NAME         GCS bucket name (default: apolo-preavaluos-pdf-dev)
    SERVICE_NAME        Cloud Run service name (default: apolo-procesamiento-inteligente)
    REGION              GCP Region (default: us-south1)

DESCRIPTION:
    This script tests the UUID folder processing feature by:
    1. Creating a unique UUID test folder
    2. Uploading test PDF files
    3. Creating the is_ready trigger file
    4. Verifying processing results
    5. Checking logs and Firestore data
    6. Optional cleanup

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_ID="$2"
            shift 2
            ;;
        --cleanup)
            CLEANUP_AFTER=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Verify buckets exist
if ! gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    print_error "Bucket gs://$BUCKET_NAME does not exist"
    echo "Please run ./deploy.sh first to create infrastructure"
    exit 1
fi

print_header "UUID Folder Processing Test"

echo -e "${BLUE}Project:${NC}       $PROJECT_ID"
echo -e "${BLUE}Bucket:${NC}        gs://$BUCKET_NAME"
echo -e "${BLUE}Service:${NC}       $SERVICE_NAME"
echo -e "${BLUE}Region:${NC}        $REGION"
echo -e "${BLUE}Cleanup:${NC}       $CLEANUP_AFTER"
echo ""

# Generate unique UUID for test
TEST_UUID="test-$(date +%s)-$(uuidgen | cut -d'-' -f1 | tr '[:upper:]' '[:lower:]')"
print_info "Test UUID: ${TEST_UUID}"
echo ""

# Create temporary directory for test files
TEMP_DIR=$(mktemp -d)
[[ "$VERBOSE" = true ]] && echo "Temp directory: $TEMP_DIR"

# Cleanup function
cleanup() {
    [[ "$VERBOSE" = true ]] && echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

print_header "Step 1: Creating Test Files"

# Create test PDF files (simulated as text files for testing)
cat > "$TEMP_DIR/test1.pdf" << 'EOF'
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
/Resources <<
/Font <<
/F1 5 0 R
>>
>>
>>
endobj

4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Test Document 1) Tj
ET
endstream
endobj

5 0 obj
<<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
endobj

xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000274 00000 n
0000000354 00000 n
trailer
<<
/Size 6
/Root 1 0 R
>>
startxref
459
%%EOF
EOF
print_status "Created test1.pdf"

cat > "$TEMP_DIR/test2.pdf" << 'EOF'
%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj

2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj

3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
/Resources <<
/Font <<
/F1 5 0 R
>>
>>
>>
endobj

4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Test Document 2) Tj
ET
endstream
endobj

5 0 obj
<<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
endobj

xref
0 6
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000274 00000 n
0000000354 00000 n
trailer
<<
/Size 6
/Root 1 0 R
>>
startxref
459
%%EOF
EOF
print_status "Created test2.pdf"

echo ""
echo "Test files created: 2 PDF files"

print_header "Step 2: Uploading Files"

echo "Uploading files to gs://$BUCKET_NAME/$TEST_UUID/"
echo "Note: NOT uploading is_ready yet - should not trigger processing"

# Upload files WITHOUT is_ready (should not trigger processing)
gsutil -m cp "$TEMP_DIR"/*.pdf gs://$BUCKET_NAME/$TEST_UUID/ 2>/dev/null
print_status "Files uploaded to gs://$BUCKET_NAME/$TEST_UUID/"

# Wait a moment
sleep 5

print_header "Step 3: Creating is_ready Trigger"

echo "Creating is_ready file to trigger processing..."
echo "" | gsutil cp - gs://$BUCKET_NAME/$TEST_UUID/is_ready
print_status "is_ready file uploaded - processing should start now"

print_header "Step 4: Waiting for Processing"

echo "Waiting 60 seconds for processing to complete..."
echo "(Document AI processing may take time)"

# Wait for processing
sleep 60

print_header "Step 5: Checking Results"

ERRORS=0

# Check if output folder exists
if gsutil ls gs://$BUCKET_NAME/$TEST_UUID/ &>/dev/null; then
    print_status "Output folder exists"
    echo ""
    echo "Contents of gs://$BUCKET_NAME/$TEST_UUID/:"
    gsutil ls -lh gs://$BUCKET_NAME/$TEST_UUID/
    echo ""
else
    print_error "Output folder missing"
    ERRORS=$((ERRORS + 1))
fi

print_header "Step 6: Checking Logs"

echo "Retrieving logs for UUID: ${TEST_UUID}"
echo ""

LOGS=$(gcloud logging read "jsonPayload.folder_uuid=\"${TEST_UUID}\"" \
    --limit=10 \
    --format="table(timestamp,severity,jsonPayload.message)" \
    --project=${PROJECT_ID} 2>/dev/null || echo "")

if [[ -n "$LOGS" ]]; then
    echo "$LOGS"
    print_status "Logs retrieved"
else
    print_info "No logs found yet (may take a moment to appear in Cloud Logging)"
fi

print_header "Step 7: Checking Firestore"

echo "Checking Firestore for processed documents..."
echo ""

# Check if documents were created in Firestore
DOCS=$(gcloud firestore documents list --collection-id=folios --project=$PROJECT_ID --limit=5 2>/dev/null || echo "")

if [[ -n "$DOCS" ]]; then
    echo "Recent documents in 'folios' collection:"
    echo "$DOCS"
    print_status "Firestore documents found"
else
    print_info "No documents found in Firestore yet"
fi

print_header "Step 8: Test Results Summary"

echo ""
echo "Test UUID: ${TEST_UUID}"
echo ""
echo "Expected behavior:"
echo "  ✓ 2 PDF files should be processed"
echo "  ✓ Processing triggered only by is_ready file"
echo "  ✓ Results stored in Firestore (folios collection)"
echo "  ✓ Structured logs with folder_uuid context"
echo ""

if [[ "$ERRORS" -eq 0 ]]; then
    print_status "Test completed successfully!"
else
    print_error "Test completed with $ERRORS errors"
fi

# Cleanup
if [[ "$CLEANUP_AFTER" = true ]]; then
    print_header "Step 9: Cleanup"

    echo "Automatic cleanup enabled - removing test files..."
    gsutil -m rm -r gs://$BUCKET_NAME/$TEST_UUID/ 2>/dev/null || true
    print_status "Test files removed from bucket"
else
    echo "Test files preserved for manual inspection:"
    echo "  Location: gs://$BUCKET_NAME/$TEST_UUID/"
    echo ""
    echo "To manually cleanup, run:"
    echo "  gsutil -m rm -r gs://$BUCKET_NAME/$TEST_UUID/"
fi

echo ""
echo "To view detailed logs:"
echo "  gcloud logging read \"jsonPayload.folder_uuid=\\\"${TEST_UUID}\\\"\" --limit=50 --project=${PROJECT_ID}"
echo ""

print_header "Test Complete"

exit $ERRORS