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
HARBOR_URL="http://harbor.apollo.io:30003"
HARBOR_USERNAME="admin"
HARBOR_PASSWORD="Harbor12345"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REGISTRIES_FILE="${SCRIPT_DIR}/registries.json"

# Check if registries.json exists
if [[ ! -f "$REGISTRIES_FILE" ]]; then
  log_error "registries.json file not found at: $REGISTRIES_FILE"
  exit 1
fi

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

# Function to test Harbor authentication
test_harbor_auth() {
  log_step "Testing Harbor authentication"
  
  # Create base64 encoded credentials for Basic Auth
  AUTH_HEADER="Basic $(echo -n "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" | base64)"
  
  # Test authentication by getting current user info
  local response=$(curl -s -w "%{http_code}" \
    -H "Authorization: ${AUTH_HEADER}" \
    "${HARBOR_URL}/api/v2.0/users/current")
  
  local http_code="${response: -3}"
  
  if [[ "$http_code" != "200" ]]; then
    log_error "Failed to authenticate with Harbor (HTTP ${http_code})"
    log_info "Please check your Harbor credentials"
    log_info "Username: ${HARBOR_USERNAME}"
    log_info "Make sure the password is correct and the user has API access"
    exit 1
  fi
  
  log_success "Successfully authenticated with Harbor"
}

# Function to check if project exists
project_exists() {
  local project_name="$1"
  
  local response=$(curl -s -w "%{http_code}" \
    -H "Authorization: ${AUTH_HEADER}" \
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
    -H "Authorization: ${AUTH_HEADER}" \
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
    -H "Authorization: ${AUTH_HEADER}" \
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

# Set up authentication header
AUTH_HEADER="Basic $(echo -n "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" | base64)"

# Test authentication
test_harbor_auth

# List existing projects
list_projects

# Create registries
log_step "Creating Harbor registries from $REGISTRIES_FILE"

# Read and parse the JSON file
REGISTRIES_JSON=$(cat "$REGISTRIES_FILE")

# Parse each registry from the JSON
echo "$REGISTRIES_JSON" | jq -c '.[]' | while read -r registry; do
  project_name=$(echo "$registry" | jq -r '.name')
  project_description=$(echo "$registry" | jq -r '.description')
  
  log_info "Processing registry: $project_name"
  create_harbor_project "$project_name" "$project_description"
done

# No cleanup needed for Basic Auth

# Final status
echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}    Harbor Registries Created Successfully! 📦${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"

# List projects again to show the result
list_projects

echo -e "${CYAN}${BOLD}Registry Usage Examples:${NC}"

# Show usage examples based on created registries
echo "$REGISTRIES_JSON" | jq -r '.[0:2] | .[] | .name' | while read -r registry_name; do
  echo -e "${BLUE}Tag and push to ${registry_name}:${NC}"
  echo -e "  docker tag myapp:latest harbor.apollo.io:30003/${registry_name}/myapp:latest"
  echo -e "  docker push harbor.apollo.io:30003/${registry_name}/myapp:latest"
  echo -e ""
done

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