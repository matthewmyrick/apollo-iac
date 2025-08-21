#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}${1}"; }
log_success() { echo -e "${GREEN}✅ ${NC}${1}"; }
log_error() { echo -e "${RED}❌ ${NC}${1}"; }

# Check if client_id is provided
if [[ -z "$1" ]]; then
    log_error "Usage: $0 <client_id>"
    echo ""
    echo "Get your OAuth client_id from:"
    echo "https://login.tailscale.com/admin/settings/oauth"
    echo ""
    echo "Example:"
    echo "  $0 k123abc..."
    exit 1
fi

CLIENT_ID="$1"
CLIENT_SECRET="***REMOVED_SECRET***"
NAMESPACE="tailscale-operator"
SECRET_NAME="operator-oauth"

log_info "Creating sealed secret for Tailscale OAuth credentials"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEALED_SECRET_FILE="${SCRIPT_DIR}/tailscale-oauth-sealedsecret.yaml"

# Check if kubeseal is available
if ! command -v kubeseal &> /dev/null; then
    log_error "kubeseal CLI not found. Please install it first:"
    echo "  brew install kubeseal"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Create the secret and seal it
log_info "Creating sealed secret..."

kubectl create secret generic "$SECRET_NAME" \
    --namespace="$NAMESPACE" \
    --from-literal=client_id="$CLIENT_ID" \
    --from-literal=client_secret="$CLIENT_SECRET" \
    --dry-run=client -o yaml | \
kubeseal \
    --controller-namespace=sealed-secrets \
    --controller-name=sealed-secrets-controller \
    --format=yaml > "$SEALED_SECRET_FILE"

if [[ $? -eq 0 ]]; then
    log_success "Sealed secret created: $SEALED_SECRET_FILE"
    
    # Show the sealed secret content (safe to commit)
    echo ""
    log_info "Generated sealed secret (safe to commit to git):"
    echo ""
    cat "$SEALED_SECRET_FILE"
    
    echo ""
    log_info "Next steps:"
    echo "1. Review the sealed secret file above"
    echo "2. Apply it: kubectl apply -f $SEALED_SECRET_FILE"
    echo "3. Restart Tailscale operator: kubectl rollout restart deployment/operator -n tailscale-operator"
    echo "4. Commit the sealed secret to git (it's encrypted and safe)"
    
else
    log_error "Failed to create sealed secret"
    exit 1
fi