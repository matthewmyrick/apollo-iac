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
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║          Apollo Local URL Mappings Setup              ║"
  echo "║        Configure /etc/hosts for Apollo Services       ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Host mappings configuration
declare -A HOST_MAPPINGS=(
  ["home.apollo.io"]="100.96.78.104"
)

# Service port mappings (for reference)
declare -A SERVICE_PORTS=(
  ["Harbor"]="30003"
  ["ArgoCD"]="30969"
  ["Vault UI"]="30201"
  ["Vault API"]="30200"
)

# Function to check if running with sudo
check_sudo() {
  if [[ $EUID -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# Function to check if entry exists in /etc/hosts
entry_exists() {
  local hostname="$1"
  local ip="$2"
  
  if grep -q "^${ip}[[:space:]]*.*${hostname}" /etc/hosts 2>/dev/null; then
    return 0
  fi
  
  return 1
}

# Function to add host entry
add_host_entry() {
  local hostname="$1"
  local ip="$2"
  
  if entry_exists "$hostname" "$ip"; then
    log_warning "Entry for ${hostname} already exists in /etc/hosts"
    return 0
  fi
  
  # Add the entry
  echo "${ip} ${hostname}" >> /etc/hosts
  
  if [[ $? -eq 0 ]]; then
    log_success "Added mapping: ${ip} → ${hostname}"
    # Verify the entry was added
    if grep -q "${hostname}" /etc/hosts; then
      log_info "Verified: Entry is now in /etc/hosts"
    else
      log_warning "Entry may not have been added correctly"
    fi
    return 0
  else
    log_error "Failed to add mapping for ${hostname}"
    return 1
  fi
}

# Function to remove host entries
remove_host_entries() {
  log_step "Removing existing Apollo host entries"
  
  for hostname in "${!HOST_MAPPINGS[@]}"; do
    if grep -q "${hostname}" /etc/hosts 2>/dev/null; then
      # Use sed to remove lines containing the hostname
      sed -i.bak "/${hostname}/d" /etc/hosts
      log_success "Removed existing entry for ${hostname}"
    fi
  done
}

# Function to test connectivity
test_connectivity() {
  log_info "Testing service connectivity..."
  
  for service in "${!SERVICE_PORTS[@]}"; do
    local port="${SERVICE_PORTS[$service]}"
    
    if curl -s -f -m 2 "http://home.apollo.io:${port}" > /dev/null 2>&1 || \
       curl -s -m 2 "http://home.apollo.io:${port}" 2>&1 | grep -q "Harbor\|ArgoCD\|Vault"; then
      log_success "${service} (port ${port}) is reachable"
    else
      log_warning "${service} (port ${port}) is not responding (service may not be running)"
    fi
  done
}

# Function to display current mappings
display_mappings() {
  log_step "Current Apollo host mappings in /etc/hosts"
  
  echo -e "${CYAN}${BOLD}Configured Mappings:${NC}"
  for hostname in "${!HOST_MAPPINGS[@]}"; do
    if grep -q "${hostname}" /etc/hosts 2>/dev/null; then
      local entry=$(grep "${hostname}" /etc/hosts | head -n1)
      echo -e "${GREEN}  ✓ ${entry}${NC}"
    else
      echo -e "${YELLOW}  ✗ ${hostname} (not configured)${NC}"
    fi
  done
  echo ""
}

# Main execution
print_banner

# Check if running with sudo
if ! check_sudo; then
  log_error "This script must be run with sudo to modify /etc/hosts"
  echo -e "${YELLOW}Please run:${NC} ${BOLD}sudo $0${NC}"
  exit 1
fi

# Parse command line arguments
ACTION="${1:-add}"

case "$ACTION" in
  add)
    log_step "Adding Apollo host mappings to /etc/hosts"
    
    # Backup /etc/hosts
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
    log_success "Created backup of /etc/hosts"
    
    # Add host entries
    for hostname in "${!HOST_MAPPINGS[@]}"; do
      add_host_entry "$hostname" "${HOST_MAPPINGS[$hostname]}"
    done
    
    echo ""
    display_mappings
    
    # Test connectivity
    log_step "Testing connectivity to services"
    test_connectivity
    ;;
    
  remove)
    log_step "Removing Apollo host mappings from /etc/hosts"
    
    # Backup /etc/hosts
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
    log_success "Created backup of /etc/hosts"
    
    remove_host_entries
    
    echo ""
    display_mappings
    ;;
    
  status)
    display_mappings
    
    # Test connectivity
    log_step "Testing connectivity to services"
    test_connectivity
    ;;
    
  *)
    log_error "Invalid action: $ACTION"
    echo ""
    echo "Usage: $0 [add|remove|status]"
    echo "  add    - Add Apollo host mappings to /etc/hosts (default)"
    echo "  remove - Remove Apollo host mappings from /etc/hosts"
    echo "  status - Show current mappings and test connectivity"
    exit 1
    ;;
esac

# Display service URLs
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}       Apollo Services Local URL Configuration 🚀${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}${BOLD}Service URLs:${NC}"
echo -e "${BLUE}Harbor Registry:${NC} http://home.apollo.io:30003"
echo -e "  ${YELLOW}Default credentials:${NC} admin / Harbor12345"
echo ""
echo -e "${BLUE}ArgoCD:${NC} http://home.apollo.io:30969"
echo -e "  ${YELLOW}Get password:${NC} kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo -e "${BLUE}Vault UI:${NC} http://home.apollo.io:30201"
echo -e "${BLUE}Vault API:${NC} http://home.apollo.io:30200"
echo ""

echo -e "${YELLOW}${BOLD}💡 Tips:${NC}"
echo -e "${BLUE}• Run 'sudo $0 status' to check current mappings${NC}"
echo -e "${BLUE}• Run 'sudo $0 remove' to remove mappings${NC}"
echo -e "${BLUE}• Mappings are stored in /etc/hosts${NC}"
echo -e "${BLUE}• Backups are created before any modifications${NC}"
echo ""

# Show reminder if services aren't running
if [[ "$ACTION" == "add" ]] || [[ "$ACTION" == "status" ]]; then
  echo -e "${YELLOW}${BOLD}Note:${NC}"
  echo -e "If services are not reachable, ensure they are deployed:"
  echo -e "  • Harbor: ${CYAN}kubectl get pods -n registry${NC}"
  echo -e "  • ArgoCD: ${CYAN}kubectl get pods -n argocd${NC}"
  echo -e "  • Vault:  ${CYAN}kubectl get pods -n vault${NC}"
fi