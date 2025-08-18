# Apollo Kubernetes Applications - Service Port Mappings

## Quick Access URLs

All services are accessible via `home.apollo.io` with their respective ports:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Harbor Registry** | 30003 | http://home.apollo.io:30003 | Container registry for Docker images |
| **ArgoCD** | 30969 | http://home.apollo.io:30969 | GitOps continuous delivery tool |
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

# Open Vault UI in browser
open http://home.apollo.io:30201

# Test connectivity
curl -I http://home.apollo.io:30003  # Harbor
curl -I http://home.apollo.io:30969  # ArgoCD
curl -I http://home.apollo.io:30201  # Vault UI
```