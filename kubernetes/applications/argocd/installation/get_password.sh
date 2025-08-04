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
    echo "║          ArgoCD Password Retrieval        ║"
    echo "║           for Apollo Cluster              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Start
print_banner

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
        log_info "Available contexts:"
        kubectl config get-contexts
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

# Check if admin secret exists
if ! kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    log_error "ArgoCD admin secret not found. ArgoCD may not be properly installed."
    exit 1
fi
log_success "ArgoCD admin secret found"

# Get the cluster server IP from kubeconfig
CLUSTER_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="apollo")].cluster.server}' | sed 's|https://||' | cut -d: -f1)
if [ -z "$CLUSTER_SERVER" ]; then
    log_warning "Could not extract server IP from apollo context, trying to get from nodes..."
    CLUSTER_SERVER=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

# Retrieve admin password
log_step "Retrieving ArgoCD Admin Password"
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    if [ -z "$ADMIN_PASSWORD" ]; then
        log_warning "Secret exists but password is empty, using default password"
        ADMIN_PASSWORD="admin123"
    fi
else
    log_warning "Initial Admin secret not found, using default password"
    ADMIN_PASSWORD="admin123"
fi

log_success "Admin password retrieved: $ADMIN_PASSWORD"

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}       ArgoCD Access Information 🔐${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Access Information:${NC}"
echo -e "${BLUE}ArgoCD URL:${NC} ${GREEN}${BOLD}http://$CLUSTER_SERVER:30969${NC}"
echo -e "${BLUE}Copy & paste to Chrome:${NC} ${YELLOW}http://$CLUSTER_SERVER:30969${NC}"
echo -e ""

echo -e "${CYAN}${BOLD}Login Credentials:${NC}"
echo -e "${BLUE}Username:${NC} admin"
echo -e "${BLUE}Password:${NC} ${YELLOW}${BOLD}${ADMIN_PASSWORD}${NC}"
echo -e ""

echo -e "${CYAN}${BOLD}Quick Commands:${NC}"
echo -e "${BLUE}Port Forward:${NC} kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo -e "${BLUE}Get Password:${NC} kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo -e ""

echo -e "${YELLOW}${BOLD}💡 Tip:${NC} You can run this script anytime to get the current ArgoCD password!"
echo -e ""