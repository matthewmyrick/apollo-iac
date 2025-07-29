# Vault Usage Guide

## Adding Secrets from Any Tailscale Device

After running `06a-key-vault.sh`, you can add secrets to Vault from any device on your Tailscale network.

### Prerequisites
1. Vault must be deployed and accessible via `https://vault.tailnet`
2. You need the root token (displayed during setup)
3. Vault CLI installed on your device (optional, can use curl)

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

# Login with root token (replace with your actual token)
vault login YOUR_ROOT_TOKEN_HERE

# Add Tailscale auth key and client ID/secret
vault kv put secret/tailscale auth_key="YOUR_TAILSCALE_AUTH_KEY"
vault kv put secret/oauth client_id="YOUR_CLIENT_ID" client_secret="YOUR_CLIENT_SECRET"

# Verify secrets were added
vault kv list secret/
vault kv get secret/tailscale
vault kv get secret/oauth
```

### Method 2: Using curl (REST API)

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
2. Login with your root token
3. Go to "Secrets" → "secret/"
4. Click "Create secret +"
5. Add your secrets:
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

### Common Secret Paths

- `secret/tailscale` - Tailscale auth keys
- `secret/oauth` - OAuth client credentials
- `secret/database` - Database credentials
- `secret/api` - API keys and tokens
- `secret/ssl` - SSL certificates and keys