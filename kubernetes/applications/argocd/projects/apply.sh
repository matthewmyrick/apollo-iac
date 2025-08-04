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
    echo "║       ArgoCD Projects Configuration       ║"
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

# Check if ArgoCD CRDs are installed
log_info "Checking for ArgoCD AppProject CRD..."
if ! kubectl get crd appprojects.argoproj.io &>/dev/null; then
    log_error "ArgoCD AppProject CRD not found. Please ensure ArgoCD is properly installed."
    exit 1
fi
log_success "ArgoCD CRDs are available"

# Apply project configurations
log_step "Applying project configurations"

# Count projects in config file
PROJECT_COUNT=$(grep -c "kind: AppProject" "$CONFIG_FILE" 2>/dev/null || echo "0")
log_info "Found $PROJECT_COUNT projects to configure"

# Apply the configuration
if kubectl apply -f "$CONFIG_FILE" &>/dev/null; then
    log_success "Project configurations applied successfully"
else
    log_error "Failed to apply project configurations"
    log_info "Checking for specific errors..."
    kubectl apply -f "$CONFIG_FILE"
    exit 1
fi

# Verify projects were created
log_step "Verifying project creation"
sleep 2  # Give Kubernetes time to process

EXPECTED_PROJECTS=("portfolio-site" "telemetry" "storage")
CREATED_COUNT=0

for project in "${EXPECTED_PROJECTS[@]}"; do
    if kubectl get appproject "$project" -n argocd &>/dev/null; then
        log_success "Project '$project' created successfully"
        CREATED_COUNT=$((CREATED_COUNT + 1))
    else
        log_error "Project '$project' not found after creation"
    fi
done

# Display results
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}     Projects Configuration Applied! 📋${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Projects Created:${NC} $CREATED_COUNT/${#EXPECTED_PROJECTS[@]}"
echo -e ""
echo -e "${CYAN}${BOLD}Configured Projects:${NC}"
for project in "${EXPECTED_PROJECTS[@]}"; do
    echo -e "${BLUE}• $project${NC} - $(kubectl get appproject "$project" -n argocd -o jsonpath='{.spec.description}' 2>/dev/null || echo 'Description not available')"
done
echo -e ""

# Show current projects
log_step "Current ArgoCD Projects"
echo -e "${CYAN}${BOLD}All available projects:${NC}"
kubectl get appprojects -n argocd --no-headers 2>/dev/null | while read -r name rest; do
    description=$(kubectl get appproject "$name" -n argocd -o jsonpath='{.spec.description}' 2>/dev/null || echo 'No description')
    echo -e "${BLUE}• $name${NC} - $description"
done

echo -e ""
echo -e "${YELLOW}${BOLD}💡 Next Steps:${NC}"
echo -e "${BLUE}• Update repository configurations to use specific projects${NC}"
echo -e "${BLUE}• Create applications and assign them to appropriate projects${NC}"
echo -e "${BLUE}• Configure project-specific RBAC if needed${NC}"
echo -e ""