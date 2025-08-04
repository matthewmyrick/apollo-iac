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
    echo "║       ArgoCD Clusters Configuration       ║"
    echo "║           for Apollo Cluster              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Protected clusters that should never be modified
PROTECTED_CLUSTERS=(
    "https://kubernetes.default.svc"
    "in-cluster"
)

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

# Get ArgoCD admin password and login
log_step "Authenticating with ArgoCD"
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_success "Admin password retrieved"
else
    log_error "ArgoCD admin secret not found. Please ensure ArgoCD is properly installed."
    exit 1
fi

# Set up port-forward for ArgoCD access
log_info "Setting up connection to ArgoCD server..."
kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 5

# Login to ArgoCD
if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
    log_success "Successfully logged into ArgoCD"
else
    kill $PORT_FORWARD_PID 2>/dev/null || true
    log_error "Failed to login to ArgoCD"
    exit 1
fi

# Check for protected clusters
log_step "Checking existing clusters"
echo -e "${CYAN}${BOLD}Protected clusters (will not be modified):${NC}"
for protected in "${PROTECTED_CLUSTERS[@]}"; do
    echo -e "${BLUE}• $protected${NC}"
done
echo ""

# Parse configuration file for clusters
log_step "Processing cluster configurations"

# Simple check if clusters are defined in config
CLUSTER_COUNT=$(grep -c "name:" "$CONFIG_FILE" 2>/dev/null | grep -v "^#" || echo "0")

if [ "$CLUSTER_COUNT" -eq 0 ]; then
    log_info "No additional clusters defined in configuration"
    log_info "This is expected for single-cluster setups"
else
    log_info "Found $CLUSTER_COUNT additional clusters to process"
    
    # Parse YAML for cluster configurations (simplified parsing)
    # Note: This is a basic implementation. For production, consider using yq or jq
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.*)\" ]]; then
            CLUSTER_NAME="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^[[:space:]]*server:[[:space:]]*\"(.*)\" ]] && [[ -n "$CLUSTER_NAME" ]]; then
            CLUSTER_SERVER="${BASH_REMATCH[1]}"
            
            # Check if this is a protected cluster
            IS_PROTECTED=false
            for protected in "${PROTECTED_CLUSTERS[@]}"; do
                if [[ "$CLUSTER_SERVER" == "$protected" ]]; then
                    IS_PROTECTED=true
                    break
                fi
            done
            
            if [ "$IS_PROTECTED" = true ]; then
                log_warning "Skipping protected cluster: $CLUSTER_NAME ($CLUSTER_SERVER)"
            else
                log_info "Processing cluster: $CLUSTER_NAME"
                log_info "Cluster server: $CLUSTER_SERVER"
                
                # Check if cluster already exists
                if argocd cluster list -o server 2>/dev/null | grep -q "^$CLUSTER_SERVER$"; then
                    log_warning "Cluster $CLUSTER_NAME already exists, skipping..."
                else
                    log_warning "Cluster addition requires manual configuration with proper authentication"
                    log_info "Please use: argocd cluster add <kubeconfig-context> --name $CLUSTER_NAME"
                fi
            fi
            
            # Reset for next cluster
            CLUSTER_NAME=""
            CLUSTER_SERVER=""
        fi
    done < "$CONFIG_FILE"
fi

# Clean up port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Display current clusters
log_step "Current ArgoCD Clusters"
kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 3

if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
    echo -e "${CYAN}${BOLD}Currently configured clusters:${NC}"
    argocd cluster list 2>/dev/null || log_warning "Could not list clusters"
fi

kill $PORT_FORWARD_PID 2>/dev/null || true

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}     Clusters Configuration Applied! 🏗️${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}${BOLD}🛡️  Security Notes:${NC}"
echo -e "${BLUE}• Default cluster (https://kubernetes.default.svc) is protected${NC}"
echo -e "${BLUE}• Additional clusters require proper authentication setup${NC}"
echo -e "${BLUE}• Use kubeconfig contexts or service account tokens${NC}"
echo -e ""

echo -e "${YELLOW}${BOLD}💡 Adding New Clusters:${NC}"
echo -e "${BLUE}1. Configure cluster access in your kubeconfig${NC}"
echo -e "${BLUE}2. Test connectivity: kubectl --context=<context> get nodes${NC}"
echo -e "${BLUE}3. Add to ArgoCD: argocd cluster add <context> --name <name>${NC}"
echo -e "${BLUE}4. Update config.yaml with cluster details${NC}"
echo -e ""