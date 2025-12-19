#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Script header
clear
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}Apolo Document Processing - Code Update Script${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
print_info "This script will:"
echo "  1. Navigate to repository root"
echo "  2. Discard local Cloud Shell changes"
echo "  3. Pull latest code from GitHub"
echo "  4. Set script permissions"
echo "  5. Redeploy the service with new code"
echo ""

# Confirmation
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Aborted by user"
    exit 1
fi

# Step 1: Navigate to repository root
print_header "Step 1: Navigating to Repository"
cd ~/apolo_procesamiento_inteligente_preavaluo || {
    print_error "Failed to navigate to repository"
    exit 1
}
print_status "In directory: $(pwd)"

# Step 2: Check git status
print_header "Step 2: Checking Git Status"
if git status --porcelain | grep -q .; then
    print_info "Local changes detected in Cloud Shell"
    git status --short
    echo ""
    print_info "These changes will be discarded to pull latest code"
else
    print_info "No local changes detected"
fi

# Step 3: Fetch and reset to latest
print_header "Step 3: Fetching Latest Code"
git fetch origin main || {
    print_error "Failed to fetch from GitHub"
    exit 1
}
print_status "Fetched latest from origin/main"

print_info "Resetting to origin/main (discarding local changes)..."
git reset --hard origin/main || {
    print_error "Failed to reset to origin/main"
    exit 1
}
print_status "Code updated to latest version"

# Show current commit
CURRENT_COMMIT=$(git log -1 --oneline)
print_info "Current commit: ${CURRENT_COMMIT}"

# Step 4: Set permissions
print_header "Step 4: Setting Script Permissions"
cd "Cloud Shell" || {
    print_error "Failed to navigate to Cloud Shell directory"
    exit 1
}
chmod +x *.sh || {
    print_error "Failed to set execute permissions"
    exit 1
}
print_status "Execute permissions set on all scripts"

# Step 5: Redeploy
print_header "Step 5: Redeploying Service"
print_info "Starting deployment with --resume --skip-tests flags..."
echo ""

./deploy.sh --resume --skip-tests

# Check exit code
if [ $? -eq 0 ]; then
    print_header "✓ Update Complete"
    echo ""
    print_status "Service redeployed with latest code"
    echo ""
    print_info "Next steps:"
    echo "  • Run tests: ./test_uuid_processing.sh"
    echo "  • View logs: gcloud run services logs tail apolo-procesamiento-inteligente --region=us-south1"
    echo ""
else
    print_header "✗ Deployment Failed"
    print_error "Check the output above for error details"
    exit 1
fi