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
    echo "║      HashiCorp Vault Deployment          ║"
    echo "║           for Apollo Cluster              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_YAML="$SCRIPT_DIR/argocd.yaml"

# Start
print_banner

# Check if ArgoCD YAML exists
if [ ! -f "$ARGOCD_YAML" ]; then
    log_error "ArgoCD configuration file not found: $ARGOCD_YAML"
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

# Check if storage project exists
log_info "Checking for 'storage' project..."
if ! kubectl get appproject storage -n argocd &>/dev/null; then
    log_error "ArgoCD 'storage' project not found. Please run the projects configuration first:"
    log_info "cd ../argocd/projects && ./apply.sh"
    exit 1
fi
log_success "Storage project found"

# Check if HashiCorp Helm repository is configured
log_step "Verifying repository configuration"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
if [ -z "$ADMIN_PASSWORD" ]; then
    log_error "Could not retrieve ArgoCD admin password"
    exit 1
fi

# Set up port-forward for ArgoCD access (in background)
kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 3

# Check repository
if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
    if argocd repo list -o name 2>/dev/null | grep -q "https://helm.releases.hashicorp.com"; then
        log_success "HashiCorp Helm repository is configured"
    else
        log_warning "HashiCorp Helm repository not found, adding it..."
        if argocd repo add https://helm.releases.hashicorp.com --type helm --name hashicorp-helm-charts &>/dev/null; then
            log_success "HashiCorp Helm repository added"
        else
            log_error "Failed to add HashiCorp Helm repository"
            kill $PORT_FORWARD_PID 2>/dev/null || true
            exit 1
        fi
    fi
else
    log_error "Failed to login to ArgoCD"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

# Clean up port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Apply the ArgoCD application
log_step "Deploying HashiCorp Vault Application"
log_info "Applying ArgoCD application configuration..."

if kubectl apply -f "$ARGOCD_YAML" &>/dev/null; then
    log_success "ArgoCD application configuration applied successfully"
else
    log_error "Failed to apply ArgoCD application configuration"
    log_info "Trying with detailed output:"
    kubectl apply -f "$ARGOCD_YAML"
    exit 1
fi

# Wait for application to be recognized
log_info "Waiting for ArgoCD to process the application..."
sleep 5

# Check application status
log_step "Checking application status"
if kubectl get application hashicorp-vault -n argocd &>/dev/null; then
    APP_STATUS=$(kubectl get application hashicorp-vault -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    APP_HEALTH=$(kubectl get application hashicorp-vault -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    log_success "Application 'hashicorp-vault' found in ArgoCD"
    echo -e "${BLUE}Sync Status:${NC} $APP_STATUS"
    echo -e "${BLUE}Health Status:${NC} $APP_HEALTH"
else
    log_error "Application 'hashicorp-vault' not found after applying configuration"
    exit 1
fi

# Trigger sync if needed
if [ "$APP_STATUS" = "OutOfSync" ] || [ "$APP_STATUS" = "Unknown" ]; then
    log_step "Triggering application sync"
    
    # Set up port-forward again
    kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
    PORT_FORWARD_PID=$!
    sleep 3
    
    if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
        log_info "Syncing application..."
        if argocd app sync hashicorp-vault --timeout 300 2>/dev/null; then
            log_success "Application synced successfully"
        else
            log_warning "Sync may be in progress or failed. Check ArgoCD UI for details."
        fi
    fi
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

# Wait for resources to be created
log_step "Waiting for Vault resources"
log_info "Waiting for vault namespace to be created..."

# Wait up to 60 seconds for namespace
for i in {1..12}; do
    if kubectl get namespace vault &>/dev/null; then
        log_success "Vault namespace created"
        break
    fi
    if [ $i -eq 12 ]; then
        log_warning "Vault namespace not found after 60 seconds. Check ArgoCD sync status."
        break
    fi
    log_info "Waiting for namespace... ($i/12)"
    sleep 5
done

# Check for vault resources
if kubectl get namespace vault &>/dev/null; then
    log_info "Checking Vault deployment status..."
    
    # Wait for StatefulSet
    if kubectl get statefulset hashicorp-vault -n vault &>/dev/null; then
        log_success "Vault StatefulSet created"
        
        # Check pod status
        POD_STATUS=$(kubectl get pod hashicorp-vault-0 -n vault -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        echo -e "${BLUE}Pod Status:${NC} $POD_STATUS"
        
        if [ "$POD_STATUS" = "Pending" ]; then
            log_info "Pod is pending - checking for issues..."
            kubectl describe pod hashicorp-vault-0 -n vault | grep -A 5 -B 5 "Events:" || true
        fi
    else
        log_warning "Vault StatefulSet not found yet. ArgoCD may still be syncing."
    fi
    
    # Check service
    if kubectl get service hashicorp-vault -n vault &>/dev/null; then
        log_success "Vault service created"
        
        # Get NodePort
        NODEPORT=$(kubectl get service hashicorp-vault -n vault -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
        echo -e "${BLUE}NodePort:${NC} $NODEPORT"
    fi
fi

# Get cluster IP for access information
CLUSTER_SERVER=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="apollo")].cluster.server}' | sed 's|https://||' | cut -d: -f1)

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    HashiCorp Vault Deployment Applied! 🔐${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Application Information:${NC}"
echo -e "${BLUE}Name:${NC} hashicorp-vault"
echo -e "${BLUE}Project:${NC} storage"
echo -e "${BLUE}Namespace:${NC} vault"
echo -e ""

if kubectl get service hashicorp-vault -n vault &>/dev/null; then
    NODEPORT=$(kubectl get service hashicorp-vault -n vault -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    echo -e "${CYAN}${BOLD}Access Information:${NC}"
    echo -e "${BLUE}Vault UI:${NC} ${GREEN}${BOLD}http://$CLUSTER_SERVER:$NODEPORT${NC}"
    echo -e "${BLUE}Copy to browser:${NC} ${YELLOW}http://$CLUSTER_SERVER:$NODEPORT${NC}"
    echo -e ""
fi

echo -e "${CYAN}${BOLD}Monitoring Commands:${NC}"
echo -e "${BLUE}Check pods:${NC} kubectl get pods -n vault"
echo -e "${BLUE}Check services:${NC} kubectl get svc -n vault"
echo -e "${BLUE}Check application:${NC} kubectl get application hashicorp-vault -n argocd"
echo -e "${BLUE}ArgoCD UI:${NC} http://$CLUSTER_SERVER:30969"
echo -e ""

echo -e "${YELLOW}${BOLD}⚠️  Next Steps:${NC}"
echo -e "${BLUE}1. Wait for the pod to be Running (may take 1-2 minutes)${NC}"
echo -e "${BLUE}2. Access Vault UI to initialize it${NC}"
echo -e "${BLUE}3. Save the root token and unseal keys securely${NC}"
echo -e "${BLUE}4. Configure authentication methods and policies${NC}"
echo -e ""

# Show current pod status if available
if kubectl get pod hashicorp-vault-0 -n vault &>/dev/null; then
    echo -e "${CYAN}${BOLD}Current Pod Status:${NC}"
    kubectl get pod hashicorp-vault-0 -n vault -o wide 2>/dev/null || echo "Pod information not available"
    echo -e ""
fi

echo -e "${YELLOW}${BOLD}💡 Tip:${NC} Monitor deployment progress with:"
echo -e "${BLUE}kubectl get pods -n vault -w${NC}"
echo -e ""