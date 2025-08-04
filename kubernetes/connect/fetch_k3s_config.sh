#!/bin/bash
set -e

# Configuration
K3S_SERVER_SSH="${K3S_SERVER_SSH:-matthewmyrick@100.96.78.104}"
REMOTE_SCRIPT_PATH="/home/matthewmyrick/github/matthewmyrick/apollo-iac/k8s/connect/get_kubeconfig.sh"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
K3S_CONFIG_TEMP="$HOME/.kube/config-k3s-temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Fetching k3s configuration from server...${NC}"

# Fetch the k3s config from the server
if ! ssh "$K3S_SERVER_SSH" "$REMOTE_SCRIPT_PATH" > "$K3S_CONFIG_TEMP" 2>/dev/null; then
    echo -e "${RED}Failed to fetch k3s config. You may need to enter your sudo password.${NC}"
    echo -e "${YELLOW}Trying with terminal allocation for sudo...${NC}"
    
    if ! ssh -t "$K3S_SERVER_SSH" "$REMOTE_SCRIPT_PATH" > "$K3S_CONFIG_TEMP"; then
        echo -e "${RED}Failed to fetch k3s config from server${NC}"
        exit 1
    fi
fi

# Check if the fetched config is valid
if ! kubectl --kubeconfig="$K3S_CONFIG_TEMP" config view > /dev/null 2>&1; then
    echo -e "${RED}Invalid kubeconfig received from server${NC}"
    rm -f "$K3S_CONFIG_TEMP"
    exit 1
fi

# Ensure all references are renamed from default to apollo
echo -e "${YELLOW}Renaming context to apollo...${NC}"
sed -i.bak \
  -e 's/name: default/name: apollo/g' \
  -e 's/cluster: default/cluster: apollo/g' \
  -e 's/user: default/user: apollo/g' \
  -e 's/current-context: default/current-context: apollo/g' \
  "$K3S_CONFIG_TEMP"
rm -f "$K3S_CONFIG_TEMP.bak"

# Backup existing config if it exists
if [ -f "$KUBECONFIG_PATH" ]; then
    echo -e "${YELLOW}Backing up existing kubeconfig...${NC}"
    mkdir -p "$HOME/.kube/backups"
    cp "$KUBECONFIG_PATH" "$HOME/.kube/backups/config.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Check if apollo context already exists and remove it to prevent duplicates
if kubectl config get-contexts apollo &>/dev/null; then
    echo -e "${YELLOW}Removing existing apollo context to prevent duplicates...${NC}"
    kubectl config delete-context apollo &>/dev/null || true
    kubectl config delete-cluster apollo &>/dev/null || true
    kubectl config delete-user apollo &>/dev/null || true
fi

# Merge configurations
if [ -f "$KUBECONFIG_PATH" ]; then
    echo -e "${YELLOW}Merging k3s config with existing kubeconfig...${NC}"
    KUBECONFIG="$KUBECONFIG_PATH:$K3S_CONFIG_TEMP" kubectl config view --flatten > "$KUBECONFIG_PATH.merged"
    mv "$KUBECONFIG_PATH.merged" "$KUBECONFIG_PATH"
else
    echo -e "${YELLOW}Creating new kubeconfig with k3s config...${NC}"
    mv "$K3S_CONFIG_TEMP" "$KUBECONFIG_PATH"
fi

# Clean up any temp files
rm -f "$K3S_CONFIG_TEMP"
rm -f "$HOME/.kube/config-k3s"
rm -f "$HOME/.kube/config-k3s-temp"

echo -e "${GREEN}✓ Successfully updated kubeconfig${NC}"
echo ""
echo "Available contexts:"
kubectl config get-contexts

echo ""
echo -e "${GREEN}To use the apollo cluster:${NC}"
echo "  kubectl config use-context apollo"
echo ""
echo -e "${GREEN}To test the connection:${NC}"
echo "  kubectl --context=apollo get nodes"