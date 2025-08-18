#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  ${NC}${1}"; }
log_success() { echo -e "${GREEN}✅ ${NC}${1}"; }
log_warning() { echo -e "${YELLOW}⚠️  ${NC}${1}"; }
log_error() { echo -e "${RED}❌ ${NC}${1}"; }

print_banner() {
  echo -e "${BLUE}"
  echo "╔═══════════════════════════════════════════════════════╗"
  echo "║       Extract Sealed Secrets Private Key              ║"
  echo "║         For local secret decryption                   ║"
  echo "╚═══════════════════════════════════════════════════════╝"
  echo -e "${NC}\n"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

extract_private_key() {
  log_info "Extracting sealed-secrets private key..."
  
  # Check if sealed-secrets is running
  if ! kubectl get secret sealed-secrets-key -n kube-system &>/dev/null; then
    log_error "Sealed secrets key not found. Is sealed-secrets controller running?"
    exit 1
  fi
  
  # Extract the private key
  kubectl get secret sealed-secrets-key -n kube-system -o jsonpath='{.data.tls\.key}' | base64 -d > "${SCRIPT_DIR}/sealed-secrets-private.key"
  
  # Extract the certificate  
  kubectl get secret sealed-secrets-key -n kube-system -o jsonpath='{.data.tls\.crt}' | base64 -d > "${SCRIPT_DIR}/sealed-secrets-cert.crt"
  
  # Set proper permissions
  chmod 600 "${SCRIPT_DIR}/sealed-secrets-private.key"
  chmod 644 "${SCRIPT_DIR}/sealed-secrets-cert.crt"
  
  log_success "Private key extracted to: ${SCRIPT_DIR}/sealed-secrets-private.key"
  log_success "Certificate extracted to: ${SCRIPT_DIR}/sealed-secrets-cert.crt"
  
  echo ""
  log_warning "🔐 IMPORTANT: Keep these files secure!"
  echo "   - Store in password manager"
  echo "   - DO NOT commit to Git"
  echo "   - These can decrypt all your sealed secrets"
}

create_decrypt_script() {
  log_info "Creating local decrypt helper script..."
  
  cat > "${SCRIPT_DIR}/decrypt-secret.sh" << 'EOF'
#!/bin/bash

# Local Sealed Secret Decryption Helper
# Usage: ./decrypt-secret.sh my-sealed-secret.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_KEY="${SCRIPT_DIR}/sealed-secrets-private.key"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <sealed-secret-file.yaml>"
  echo ""
  echo "Example:"
  echo "  $0 my-sealed-secret.yaml"
  echo ""
  echo "This will decrypt the sealed secret and show the original values."
  exit 1
fi

SEALED_SECRET_FILE="$1"

if [[ ! -f "$SEALED_SECRET_FILE" ]]; then
  echo "Error: File $SEALED_SECRET_FILE not found"
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "Error: Private key not found at $PRIVATE_KEY"
  echo "Run ./extract-seal-key.sh first"
  exit 1
fi

echo "🔓 Decrypting $SEALED_SECRET_FILE..."
echo ""

# Use kubeseal to decrypt
kubeseal --recovery-unseal --recovery-private-key "$PRIVATE_KEY" < "$SEALED_SECRET_FILE"
EOF

  chmod +x "${SCRIPT_DIR}/decrypt-secret.sh"
  log_success "Decrypt helper created: ${SCRIPT_DIR}/decrypt-secret.sh"
}

show_usage() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}      Private Key Extraction Complete! 🔐${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${BLUE}How to decrypt secrets locally:${NC}"
  echo ""
  echo -e "${YELLOW}Method 1: Using the helper script${NC}"
  echo "  ./decrypt-secret.sh my-sealed-secret.yaml"
  echo ""
  echo -e "${YELLOW}Method 2: Direct kubeseal command${NC}"
  echo "  kubeseal --recovery-unseal \\"
  echo "    --recovery-private-key sealed-secrets-private.key \\"
  echo "    < my-sealed-secret.yaml"
  echo ""
  echo -e "${YELLOW}Method 3: Decrypt specific value${NC}"
  echo "  echo 'AgBy3i4OJSWK...' | base64 -d | \\"
  echo "    openssl rsautl -decrypt -inkey sealed-secrets-private.key"
  echo ""
  echo -e "${BLUE}Files created:${NC}"
  echo "  📄 sealed-secrets-private.key (KEEP SECURE)"
  echo "  📄 sealed-secrets-cert.crt"
  echo "  🔧 decrypt-secret.sh (helper script)"
  echo ""
  echo -e "${BLUE}Example workflow:${NC}"
  echo "  1. Create secret: kubectl create secret ... | kubeseal > secret.yaml"
  echo "  2. Commit to Git: git add secret.yaml && git commit"
  echo "  3. Decrypt locally: ./decrypt-secret.sh secret.yaml"
}

# Main execution
print_banner

case "${1:-extract}" in
  extract)
    extract_private_key
    create_decrypt_script
    show_usage
    ;;
    
  *)
    echo "Usage: $0 [extract]"
    echo "  extract - Extract private key and create decrypt tools"
    exit 1
    ;;
esac