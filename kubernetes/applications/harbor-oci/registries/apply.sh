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
  echo "║         Harbor Registry Creator           ║"
  echo "║           for Apollo Cluster              ║"
  echo "╚═══════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Harbor configuration
HARBOR_URL="http://100.96.78.104:30003"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

# Default registries to create
REGISTRIES=(
  "apollo-apps:Core Apollo applications and services"
  "apollo-infrastructure:Infrastructure components and tools"
  "apollo-dev:Development and testing images"
  "apollo-ml:Machine learning models and data science tools"
  "third-party:Mirrored third-party images"
)

# Function to check if Harbor is accessible
check_harbor_access() {
  log_step "Checking Harbor accessibility"
  
  if ! curl -s -f "${HARBOR_URL}/api/v2.0/health" > /dev/null; then
    log_error "Harbor is not accessible at ${HARBOR_URL}"
    log_info "Please ensure Harbor is running and accessible"
    exit 1
  fi
  
  log_success "Harbor is accessible"
}

# Function to get Harbor API token
get_harbor_token() {
  log_step "Authenticating with Harbor"
  
  # Try to get a token
  TOKEN_RESPONSE=$(curl -s -X POST "${HARBOR_URL}/c/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "principal=${HARBOR_USERNAME}&password=${HARBOR_PASSWORD}" \
    -c /tmp/harbor_cookies.txt \
    -w "%{http_code}")
  
  if [[ "${TOKEN_RESPONSE: -3}" != "200" ]]; then
    log_error "Failed to authenticate with Harbor"
    log_info "Please check your Harbor credentials"
    exit 1
  fi
  
  log_success "Successfully authenticated with Harbor"
}

# Function to check if project exists
project_exists() {
  local project_name="$1"
  
  local response=$(curl -s -w "%{http_code}" \
    -b /tmp/harbor_cookies.txt \
    "${HARBOR_URL}/api/v2.0/projects?name=${project_name}")
  
  local http_code="${response: -3}"
  local body="${response%???}"
  
  if [[ "$http_code" == "200" ]]; then
    # Check if the response contains any projects
    local project_count=$(echo "$body" | jq -r '. | length' 2>/dev/null || echo "0")
    if [[ "$project_count" -gt 0 ]]; then
      return 0  # Project exists
    fi
  fi
  
  return 1  # Project doesn't exist
}

# Function to create a Harbor project
create_harbor_project() {
  local project_name="$1"
  local project_description="$2"
  
  log_info "Creating project: ${project_name}"
  
  # Check if project already exists
  if project_exists "$project_name"; then
    log_warning "Project '${project_name}' already exists, skipping..."
    return 0
  fi
  
  # Create the project
  local create_response=$(curl -s -w "%{http_code}" \
    -X POST "${HARBOR_URL}/api/v2.0/projects" \
    -H "Content-Type: application/json" \
    -b /tmp/harbor_cookies.txt \
    -d "{
      \"project_name\": \"${project_name}\",
      \"metadata\": {
        \"public\": \"false\",
        \"enable_content_trust\": \"false\",
        \"prevent_vul\": \"false\",
        \"severity\": \"low\",
        \"auto_scan\": \"true\"
      },
      \"storage_limit\": -1,
      \"registry_id\": null
    }")
  
  local http_code="${create_response: -3}"
  
  if [[ "$http_code" == "201" ]]; then
    log_success "Project '${project_name}' created successfully"
  elif [[ "$http_code" == "409" ]]; then
    log_warning "Project '${project_name}' already exists"
  else
    log_error "Failed to create project '${project_name}' (HTTP ${http_code})"
    echo "Response: ${create_response%???}"
    return 1
  fi
}

# Function to list all projects
list_projects() {
  log_step "Listing all Harbor projects"
  
  local response=$(curl -s -w "%{http_code}" \
    -b /tmp/harbor_cookies.txt \
    "${HARBOR_URL}/api/v2.0/projects")
  
  local http_code="${response: -3}"
  local body="${response%???}"
  
  if [[ "$http_code" == "200" ]]; then
    echo -e "${CYAN}${BOLD}Existing Projects:${NC}"
    echo "$body" | jq -r '.[] | "• \(.name) - \(.metadata.public // "private" | if . == "true" then "public" else "private" end)"' 2>/dev/null || {
      log_warning "Could not parse project list"
      echo "$body"
    }
  else
    log_error "Failed to list projects (HTTP ${http_code})"
  fi
  
  echo ""
}

# Main execution
print_banner

# Check if jq is available
if ! command -v jq &> /dev/null; then
  log_error "jq is required but not installed. Please install jq first."
  exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
  log_error "curl is required but not installed. Please install curl first."
  exit 1
fi

# Check Harbor access
check_harbor_access

# Get authentication token
get_harbor_token

# List existing projects
list_projects

# Create registries
log_step "Creating Harbor registries"

for registry_config in "${REGISTRIES[@]}"; do
  IFS=':' read -r project_name project_description <<< "$registry_config"
  create_harbor_project "$project_name" "$project_description"
done

# Clean up temporary files
rm -f /tmp/harbor_cookies.txt

# Final status
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    Harbor Registries Created Successfully! 📦${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

# List projects again to show the result
list_projects

echo -e "${CYAN}${BOLD}Registry Usage Examples:${NC}"
echo -e "${BLUE}Tag and push to apollo-apps:${NC}"
echo -e "  docker tag myapp:latest 100.96.78.104:30003/apollo-apps/myapp:latest"
echo -e "  docker push 100.96.78.104:30003/apollo-apps/myapp:latest"
echo -e ""
echo -e "${BLUE}Tag and push to apollo-infrastructure:${NC}"
echo -e "  docker tag monitoring:latest 100.96.78.104:30003/apollo-infrastructure/monitoring:latest"
echo -e "  docker push 100.96.78.104:30003/apollo-infrastructure/monitoring:latest"
echo -e ""

echo -e "${YELLOW}${BOLD}💡 Next Steps:${NC}"
echo -e "${BLUE}1. Configure your CI/CD pipelines to use these registries${NC}"
echo -e "${BLUE}2. Set up RBAC permissions for different teams${NC}"
echo -e "${BLUE}3. Configure image scanning policies${NC}"
echo -e "${BLUE}4. Set up replication rules if needed${NC}"
echo -e ""

echo -e "${CYAN}${BOLD}Harbor Access:${NC}"
echo -e "${BLUE}Harbor UI:${NC} ${HARBOR_URL}"
echo -e "${BLUE}Username:${NC} ${HARBOR_USERNAME}"
echo -e "${BLUE}Password:${NC} ${HARBOR_PASSWORD} ${YELLOW}(Change this!)${NC}"