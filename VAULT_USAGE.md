# Vault Usage Guide

## Setup and Initialization

Vault is deployed in the `key-vault` namespace and accessible via `https://vault.tailnet`. After deployment, Vault is automatically initialized with:
- 1 key share and threshold of 1
- A root token for initial access

**Important**: Save the unseal key and root token displayed during initialization - they cannot be recovered!

## Unsealing Vault

Vault starts in a sealed state after restarts. To unseal it:

```bash
# Using kubectl
kubectl exec -n key-vault deployment/vault -- vault operator unseal YOUR_UNSEAL_KEY

# Or via API
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"key": "YOUR_UNSEAL_KEY"}' \
  https://vault.tailnet/v1/sys/unseal
```

## Adding Secrets from Any Tailscale Device

### Prerequisites
1. Vault must be deployed and accessible via `https://vault.tailnet`
2. Vault must be unsealed (see above)
3. You need the root token (displayed during initialization)
4. Vault CLI installed on your device (optional, can use curl)

### Method 1: Using Vault CLI

#### Install Vault CLI
```bash

# macOS
brew install vault

# Linux
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault

# Windows
choco install vault
```

#### Login and Add Secrets
```bash
# Set Vault address
export VAULT_ADDR=https://vault.tailnet

# Check if Vault is unsealed
vault status

# If sealed, unseal it first
vault operator unseal YOUR_UNSEAL_KEY

# Login with root token (replace with your actual token)
vault login YOUR_ROOT_TOKEN_HERE

# Enable KV secrets engine (if not already enabled)
vault secrets enable -path=secret kv-v2

# Add Tailscale auth key and client ID/secret
vault kv put secret/tailscale auth_key="YOUR_TAILSCALE_AUTH_KEY"
vault kv put secret/oauth client_id="YOUR_CLIENT_ID" client_secret="YOUR_CLIENT_SECRET"

# Verify secrets were added
vault kv list secret/
vault kv get secret/tailscale
vault kv get secret/oauth
```

### Method 2: Using curl (REST API)

#### Check Vault Status and Unseal if Needed
```bash
# Check status
curl https://vault.tailnet/v1/sys/seal-status

# If sealed, unseal it
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"key": "YOUR_UNSEAL_KEY"}' \
  https://vault.tailnet/v1/sys/unseal
```

#### Enable KV Engine (if needed)
```bash
curl -X POST \
  -H "X-Vault-Token: YOUR_ROOT_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"type": "kv-v2"}' \
  https://vault.tailnet/v1/sys/mounts/secret
```

#### Add Tailscale Auth Key
```bash
curl -X POST \
  -H "X-Vault-Token: YOUR_ROOT_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"data": {"auth_key": "YOUR_TAILSCALE_AUTH_KEY"}}' \
  https://vault.tailnet/v1/secret/data/tailscale
```

#### Add OAuth Client Credentials
```bash
curl -X POST \
  -H "X-Vault-Token: YOUR_ROOT_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"data": {"client_id": "YOUR_CLIENT_ID", "client_secret": "YOUR_CLIENT_SECRET"}}' \
  https://vault.tailnet/v1/secret/data/oauth
```

#### Retrieve Secrets
```bash
# Get Tailscale auth key
curl -H "X-Vault-Token: YOUR_ROOT_TOKEN_HERE" \
  https://vault.tailnet/v1/secret/data/tailscale

# Get OAuth credentials
curl -H "X-Vault-Token: YOUR_ROOT_TOKEN_HERE" \
  https://vault.tailnet/v1/secret/data/oauth
```

### Method 3: Using Web UI

1. Navigate to `https://vault.tailnet` in your browser
2. Check if Vault is unsealed (status shows "Unsealed")
3. If sealed, click "Unseal" and enter your unseal key
4. Login with your root token
5. Enable KV secrets engine if needed:
   - Go to "Secrets" → "Enable new engine"
   - Select "KV" and set path to "secret"
6. Go to "Secrets" → "secret/"
7. Click "Create secret +"
8. Add your secrets:
   - Path: `tailscale`, Key: `auth_key`, Value: `YOUR_TAILSCALE_AUTH_KEY`
   - Path: `oauth`, Key: `client_id`, Value: `YOUR_CLIENT_ID`
   - Path: `oauth`, Key: `client_secret`, Value: `YOUR_CLIENT_SECRET`

### Security Best Practices

1. **Token Management**: The root token has full access. Consider creating limited-privilege tokens for routine operations:
   ```bash
   vault token create -policy=secrets-policy -ttl=24h
   ```

2. **Network Security**: Vault is only accessible via your Tailscale network, providing network-level security.

3. **Secret Rotation**: Regularly rotate your secrets, especially the Tailscale auth keys.

4. **Backup**: The Vault data is stored in `/var/lib/vault-data` on your server. Ensure this is backed up.

5. **Seal Status**: Vault seals automatically on restart. Always check seal status before use and unseal if necessary.

### Troubleshooting

#### Vault is Sealed
```bash
# Check status
kubectl exec -n key-vault deployment/vault -- vault status

# Unseal if needed
kubectl exec -n key-vault deployment/vault -- vault operator unseal YOUR_UNSEAL_KEY
```

#### Pod Not Running
```bash
# Check pod status
kubectl get pods -n key-vault

# Check logs
kubectl logs -n key-vault -l app=vault

# Restart if needed
kubectl delete pod -n key-vault -l app=vault
```

### Common Secret Paths

- `secret/tailscale` - Tailscale auth keys
- `secret/oauth` - OAuth client credentials
- `secret/database` - Database credentials
- `secret/api` - API keys and tokens
- `secret/ssl` - SSL certificates and keys
