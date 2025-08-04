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
    echo "║      ArgoCD Repository Configuration      ║"
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

# Get ArgoCD admin password and login
log_step "Authenticating with ArgoCD"
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_success "Admin password retrieved"
else
    log_error "ArgoCD admin secret not found. Please ensure ArgoCD is properly installed."
    exit 1
fi

# Get ArgoCD server URL
ARGOCD_SERVER="100.96.78.104:30969"
log_info "Connecting to ArgoCD server at $ARGOCD_SERVER"

# Login to ArgoCD using port-forward (more reliable than direct connection)
log_info "Setting up port-forward to ArgoCD server..."
kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 5  # Give port-forward time to establish

# Login to ArgoCD
if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
    log_success "Successfully logged into ArgoCD"
else
    kill $PORT_FORWARD_PID 2>/dev/null || true
    log_error "Failed to login to ArgoCD. Please check if ArgoCD is running properly."
    exit 1
fi

# Parse and apply repository configurations
log_step "Processing repository configurations"

# Simple YAML parsing for repositories (assuming specific format)
REPO_COUNT=0
while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.*)\" ]]; then
        REPO_NAME="${BASH_REMATCH[1]}"
        REPO_COUNT=$((REPO_COUNT + 1))
    elif [[ $line =~ ^[[:space:]]*url:[[:space:]]*\"(.*)\" ]] && [[ -n "$REPO_NAME" ]]; then
        REPO_URL="${BASH_REMATCH[1]}"
        
        log_info "Processing repository: $REPO_NAME"
        log_info "Repository URL: $REPO_URL"
        
        # Check if repository already exists
        if argocd repo list -o name 2>/dev/null | grep -q "^$REPO_URL$"; then
            log_warning "Repository $REPO_NAME already exists, skipping..."
        else
            # Add repository (assuming public for now)
            if argocd repo add "$REPO_URL" --name "$REPO_NAME" &>/dev/null; then
                log_success "Added repository: $REPO_NAME"
            else
                log_error "Failed to add repository: $REPO_NAME"
                log_warning "If this is a private repository, you may need to provide authentication credentials in config.yaml"
            fi
        fi
        
        # Reset for next repository
        REPO_NAME=""
        REPO_URL=""
    fi
done < "$CONFIG_FILE"

# Clean up port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    Repository Configuration Applied! 📚${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Repositories Processed:${NC} $REPO_COUNT"
echo -e ""
echo -e "${YELLOW}${BOLD}💡 Notes:${NC}"
echo -e "${BLUE}• If repositories failed to add, they might be private${NC}"
echo -e "${BLUE}• For private repos, add authentication in config.yaml${NC}"
echo -e "${BLUE}• Use GitHub personal access tokens for username/password auth${NC}"
echo -e ""

# Show current repositories
log_step "Current ArgoCD Repositories"
kubectl port-forward svc/argocd-server -n argocd 8080:80 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 3

if argocd login localhost:8080 --insecure --username admin --password "$ADMIN_PASSWORD" &>/dev/null; then
    echo -e "${CYAN}${BOLD}Currently configured repositories:${NC}"
    argocd repo list 2>/dev/null || log_warning "Could not list repositories"
fi

kill $PORT_FORWARD_PID 2>/dev/null || true