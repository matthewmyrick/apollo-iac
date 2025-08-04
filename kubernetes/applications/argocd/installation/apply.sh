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
    echo "║          ArgoCD Installation              ║"
    echo "║           for Apollo Cluster              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Start installation
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

# Get the cluster server IP from kubeconfig
CLUSTER_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="apollo")].cluster.server}' | sed 's|https://||' | cut -d: -f1)
if [ -z "$CLUSTER_SERVER" ]; then
    log_warning "Could not extract server IP from apollo context, trying to get from nodes..."
    CLUSTER_SERVER=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi
log_info "Cluster server IP: $CLUSTER_SERVER"

# Create namespace for ArgoCD
log_step "Creating ArgoCD namespace"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
log_success "Namespace 'argocd' created/confirmed"

# Install ArgoCD
log_step "Installing ArgoCD"
log_info "Downloading and applying ArgoCD manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml &>/dev/null
log_success "ArgoCD manifests applied"

# Wait for ArgoCD to be ready
log_step "Waiting for ArgoCD components to initialize"
log_info "This may take a few minutes..."

deployments=("argocd-server" "argocd-repo-server" "argocd-redis" "argocd-dex-server")
for deployment in "${deployments[@]}"; do
    log_info "Waiting for $deployment..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment -n argocd &>/dev/null
    log_success "$deployment is ready"
done

# Patch ArgoCD server to use NodePort (k3s requires ports 30000-32767)
log_step "Configuring NodePort access"
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30969, "name": "https", "protocol": "TCP"}, {"port": 443, "targetPort": 8080, "nodePort": 30970, "name": "grpc", "protocol": "TCP"}]}}' &>/dev/null
log_success "ArgoCD server configured with NodePort 30969"

# Wait for pods to be ready
log_info "Waiting for ArgoCD pods to be fully ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s &>/dev/null

# Get the initial admin password
log_step "Retrieving initial admin password"
log_info "Waiting for ArgoCD to generate initial admin password..."
sleep 10  # Give ArgoCD time to create the secret

# Wait for the secret to be created
for i in {1..30}; do
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        break
    fi
    log_info "Waiting for admin secret to be created... ($i/30)"
    sleep 2
done

if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_success "Initial admin password retrieved"
    echo -e "${CYAN}${BOLD}Generated Admin Password:${NC} ${YELLOW}${ADMIN_PASSWORD}${NC}"
else
    log_warning "Admin secret not created automatically. You may need to check ArgoCD logs."
    ADMIN_PASSWORD="<check-secret-manually>"
fi


# Print success information
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}       ArgoCD Installation Complete! 🎉${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Access Information:${NC}"
echo -e "${BLUE}ArgoCD URL:${NC} ${GREEN}${BOLD}http://$CLUSTER_SERVER:30969${NC}"
echo -e "${BLUE}Copy & paste to Chrome:${NC} ${YELLOW}http://$CLUSTER_SERVER:30969${NC}"
echo -e ""
echo -e "${CYAN}${BOLD}Login Credentials:${NC}"
echo -e "${BLUE}Username:${NC} admin"
echo -e "${BLUE}Password:${NC} ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo -e ""
echo -e "${YELLOW}${BOLD}⚠️  Important Notes:${NC}"
echo -e "• Admin password: ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo -e "• Password is stored in 'argocd-initial-admin-secret' secret"
echo -e "• ArgoCD UI is accessible via NodePort 30969 (k3s requires 30000-32767 range)"
echo -e "• Alternatively, use: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo -e ""