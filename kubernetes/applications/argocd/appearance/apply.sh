#!/bin/bash

set -e

# Colors and formatting for pretty logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Pretty logging functions
log_info() {
    echo -e "${BLUE}ℹ️  ${NC}${1}"
}

log_success() {
    echo -e "${GREEN}✅ ${NC}${1}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${NC}${1}"
}

log_error() {
    echo -e "${RED}❌ ${NC}${1}"
}

log_step() {
    echo -e "\n${PURPLE}▶ ${BOLD}${1}${NC}"
}

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║        ArgoCD Appearance Configuration    ║"
    echo "║           for Apollo Cluster              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Start
print_banner

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check kubectl connection
log_step "Verifying cluster connection"
if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi
log_success "Connected to Kubernetes cluster"

# Check current context and switch to apollo if needed
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "apollo" ]; then
    log_warning "Current context is '$CURRENT_CONTEXT', switching to 'apollo'..."
    if kubectl config use-context apollo &>/dev/null; then
        log_success "Switched to 'apollo' context"
    else
        log_error "'apollo' context not found. Please ensure the k3s cluster context is named 'apollo'."
        exit 1
    fi
else
    log_info "Using kubectl context: apollo"
fi

# Check if ArgoCD namespace exists
log_step "Checking ArgoCD installation"
if ! kubectl get namespace argocd &>/dev/null; then
    log_error "ArgoCD namespace 'argocd' not found. Please install ArgoCD first."
    exit 1
fi
log_success "ArgoCD namespace found"

# Apply appearance configuration
log_step "Applying appearance configuration"
log_info "Applying dark mode and UI settings..."

# Use kubectl patch to merge the configuration instead of replace
if kubectl patch configmap argocd-cm -n argocd --type merge --patch-file "$CONFIG_FILE" &>/dev/null; then
    log_success "Appearance configuration applied successfully"
else
    log_warning "ConfigMap might not exist, creating it..."
    if kubectl apply -f "$CONFIG_FILE" &>/dev/null; then
        log_success "Appearance configuration created successfully"
    else
        log_error "Failed to apply appearance configuration"
        exit 1
    fi
fi

# Restart ArgoCD server to pick up changes
log_step "Restarting ArgoCD server"
log_info "Restarting ArgoCD server to apply appearance changes..."
kubectl rollout restart deployment argocd-server -n argocd &>/dev/null
log_info "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s &>/dev/null
log_success "ArgoCD server restarted successfully"

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    Appearance Configuration Applied! 🎨${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Changes Applied:${NC}"
echo -e "${BLUE}• Dark mode enabled${NC}"
echo -e "${BLUE}• Custom banner: 'Apollo Cluster - ArgoCD'${NC}"
echo -e "${BLUE}• External URL configured${NC}"
echo -e ""
echo -e "${YELLOW}${BOLD}💡 Note:${NC} Refresh your browser to see the dark mode changes!"
echo -e ""