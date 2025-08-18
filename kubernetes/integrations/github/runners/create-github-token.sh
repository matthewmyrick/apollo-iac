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
log_warning() { echo -e "${YELLOW}⚠️  ${NC}${1}"; }
log_error() { echo -e "${RED}❌ ${NC}${1}"; }

print_banner() {
  echo -e "${BLUE}"
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║         GitHub Token Secret Creation                  ║"
  echo "║      Required for GitHub Runner Authentication        ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

print_banner

# Check if GITHUB_TOKEN is set
if [[ -z "$GITHUB_TOKEN" ]]; then
    log_error "GITHUB_TOKEN environment variable not set"
    echo ""
    echo "Please create a GitHub Personal Access Token with these permissions:"
    echo ""
    echo "For repository-level runners:"
    echo "  ✓ repo (Full control of private repositories)"
    echo "  ✓ workflow (Update GitHub Action workflows)"
    echo ""
    echo "For organization-level runners (if needed):"
    echo "  ✓ admin:org (Full control of orgs and teams)"
    echo ""
    echo "To create a token:"
    echo "1. Go to: https://github.com/settings/tokens/new"
    echo "2. Give it a name like 'apollo-runners'"
    echo "3. Select the required scopes above"
    echo "4. Click 'Generate token'"
    echo "5. Copy the token"
    echo ""
    echo "Then run:"
    echo "  export GITHUB_TOKEN=ghp_your_token_here"
    echo "  $0"
    exit 1
fi

log_info "Creating GitHub token secret (not managed by ArgoCD)..."

# Delete existing secret if it exists
kubectl delete secret github-runner-token -n github-runners --ignore-not-found=true

# Create the secret
kubectl create secret generic github-runner-token \
    --namespace=github-runners \
    --from-literal=github_token="$GITHUB_TOKEN"

if [[ $? -eq 0 ]]; then
    log_success "GitHub token secret created successfully"
    
    # Verify the secret
    echo ""
    log_info "Verifying secret..."
    kubectl get secret github-runner-token -n github-runners
    
    # Check if data exists
    echo ""
    TOKEN_LENGTH=$(kubectl get secret github-runner-token -n github-runners -o jsonpath='{.data.github_token}' | wc -c)
    if [[ $TOKEN_LENGTH -gt 0 ]]; then
        log_success "Secret contains github_token (length: $TOKEN_LENGTH chars encoded)"
    else
        log_error "Secret is empty - token was not added properly"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}      GitHub Token Secret Ready! 🔐${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Apply the runner instances:"
    echo "   kubectl apply -f $(dirname $0)/instances/deployment/argocd.yaml"
    echo ""
    echo "2. Check the runners:"
    echo "   kubectl get autoscalingrunnersets -n github-runners"
    echo "   kubectl get pods -n github-runners"
else
    log_error "Failed to create GitHub token secret"
    exit 1
fi