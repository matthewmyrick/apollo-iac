# Apollo Kubernetes Applications - Service Port Mappings

## Quick Access URLs

All services are accessible via `home.apollo.io` with their respective ports:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Harbor Registry** | 30003 | http://home.apollo.io:30003 | Container registry for Docker images |
| **ArgoCD** | 30969 | http://home.apollo.io:30969 | GitOps continuous delivery tool |
| **Infisical** | 30500 | http://home.apollo.io:30500 | Modern secret management platform |
| **Vault UI** | 30201 | http://home.apollo.io:30201 | HashiCorp Vault web interface |
| **Vault API** | 30200 | http://home.apollo.io:30200 | HashiCorp Vault API endpoint |

## Default Credentials

### Harbor
- **Username:** admin
- **Password:** Harbor12345

### ArgoCD
- **Username:** admin
- **Password:** Get with:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```

### Infisical
- Create account via web UI on first visit
- No default credentials - admin account setup required

### Vault
- Initial root token available after initialization

## Service Status Check

Check if services are running:

```bash
# Harbor
kubectl get pods -n registry
kubectl get svc -n registry

# ArgoCD
kubectl get pods -n argocd
kubectl get svc -n argocd

# Infisical
kubectl get pods -n infisical
kubectl get svc -n infisical

# Vault
kubectl get pods -n vault
kubectl get svc -n vault
```

## Port Range Information

K3s NodePort valid range: **30000-32767**

All services use NodePort type for external access on the cluster.

## Setup Local URL Mapping

To enable `home.apollo.io` hostname:

```bash
# Run the configuration script
sudo ../setup/local/02-configure-url-mappings.sh add

# Or manually add to /etc/hosts
sudo sh -c 'echo "100.96.78.104 home.apollo.io" >> /etc/hosts'
```

## Quick Service Access

```bash
# Open Harbor in browser
open http://home.apollo.io:30003

# Open ArgoCD in browser
open http://home.apollo.io:30969

# Open Infisical in browser
open http://home.apollo.io:30500

# Open Vault UI in browser
open http://home.apollo.io:30201

# Test connectivity
curl -I http://home.apollo.io:30003  # Harbor
curl -I http://home.apollo.io:30969  # ArgoCD
curl -I http://home.apollo.io:30500  # Infisical
curl -I http://home.apollo.io:30201  # Vault UI
```

## Browser Security Configuration

Since these services run on HTTP (not HTTPS), browsers will show security warnings. Here's how to configure each browser to allow these specific local development URLs:

### Chrome

**Method 1: Command Line Flags**
```bash
# Launch Chrome with security exceptions for Apollo services
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --unsafely-treat-insecure-origin-as-secure="http://home.apollo.io:30003,http://home.apollo.io:30969,http://home.apollo.io:30500,http://home.apollo.io:30201,http://home.apollo.io:30200"
```

**Method 2: Chrome Flags (Persistent)**
1. Navigate to: `chrome://flags/#unsafely-treat-insecure-origin-as-secure`
2. Add these origins: `http://home.apollo.io:30003,http://home.apollo.io:30969,http://home.apollo.io:30500,http://home.apollo.io:30201,http://home.apollo.io:30200`
3. Click "Enable" and restart Chrome

### Firefox

**Method 1: Site Permissions**
1. Visit each URL (e.g., `http://home.apollo.io:30003`)
2. Click the lock icon in the address bar
3. Click "Connection not secure" → "More Information"
4. Go to "Permissions" tab
5. Uncheck "Use default" for relevant permissions

**Method 2: About:Config**
1. Navigate to `about:config`
2. Accept the risk warning
3. Search for: `network.stricttransportsecurity.preloadlist`
4. Set to `false` (for development only)
5. Search for: `dom.security.https_only_mode`
6. Set to `false` (for development only)

### Safari

1. **Enable Developer Menu:**
   - Safari → Settings → Advanced → Show features for web developers

2. **Disable Security for Local Development:**
   - Develop menu → Disable Cross-Origin Restrictions
   - Develop menu → Disable Local File Restrictions

3. **Allow Insecure Content:**
   - Safari → Settings → Websites → Settings for This Website
   - When on `home.apollo.io`, allow insecure content

### Edge (Microsoft)

**Method 1: Command Line Flags (Same as Chrome)**
```bash
# Launch Edge with security exceptions
/Applications/Microsoft\ Edge.app/Contents/MacOS/Microsoft\ Edge \
  --unsafely-treat-insecure-origin-as-secure="http://home.apollo.io:30003,http://home.apollo.io:30969,http://home.apollo.io:30500,http://home.apollo.io:30201,http://home.apollo.io:30200"
```

**Method 2: Edge Flags (Persistent)**
1. Navigate to: `edge://flags/#unsafely-treat-insecure-origin-as-secure`
2. Add these origins: `http://home.apollo.io:30003,http://home.apollo.io:30969,http://home.apollo.io:30500,http://home.apollo.io:30201,http://home.apollo.io:30200`
3. Click "Enable" and restart Edge

### Zen Browser

**Method 1: Inherited Firefox Settings**
Since Zen is Firefox-based, use the same approach as Firefox:
1. Navigate to `about:config`
2. Search for: `network.stricttransportsecurity.preloadlist`
3. Set to `false`
4. Search for: `dom.security.https_only_mode`
5. Set to `false`

**Method 2: Security Exceptions**
1. Visit each service URL
2. Click the shield icon in the address bar
3. Turn off "Enhanced Tracking Protection" for these sites
4. Accept any security warnings for local development

## Security Notes

⚠️ **Important:** These configurations reduce browser security checks. Only use them for:
- Local development environments
- Trusted internal services
- Never for production or public-facing services

💡 **Tip:** Consider creating a separate browser profile specifically for development to keep your main browsing profile secure.