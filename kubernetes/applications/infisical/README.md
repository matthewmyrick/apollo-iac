# Infisical - Modern Secret Management (Fresh Start)

This is a clean deployment of Infisical using the official Helm charts from the Infisical team.

## 🏗️ Architecture

- **Chart**: `infisical-standalone-postgres` (official)
- **Repository**: `https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/`
- **Database**: PostgreSQL (included in chart)
- **Cache**: Redis (included in chart)
- **Access**: NodePort on port 30500

## 🚀 Quick Deployment

```bash
cd deployment
./apply.sh
```

## 📋 Manual Steps

1. **Deploy ArgoCD Projects** (if not done):
   ```bash
   cd ../../argocd/projects && ./apply.sh
   ```

2. **Deploy Infisical**:
   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -f argocd.yaml
   ```

3. **Access UI**:
   ```
   http://home.apollo.io:30500
   ```

## 🔧 Configuration

### NodePort Access
- **Frontend**: NodePort 30500 → Port 3000
- **Backend**: ClusterIP (internal only)

### Database
- **PostgreSQL**: Included with persistent storage
- **Redis**: Included with persistent storage
- **Storage Class**: `local-path` (k3s default)

## 📊 Monitoring

```bash
# Check deployment status
kubectl get application infisical -n argocd

# Check pods
kubectl get pods -n infisical

# Check services
kubectl get svc -n infisical

# View logs
kubectl logs -n infisical deployment/infisical-backend
kubectl logs -n infisical deployment/infisical-frontend
```

## 🆚 Differences from Previous Attempt

| Previous | New Approach |
|----------|-------------|
| Custom configuration | Official Helm chart |
| Manual secret creation | Chart handles setup |
| Complex migration logic | Built-in database setup |
| Multiple repositories | Single official repo |
| Custom values structure | Standard chart values |

## 🔒 Security

The official chart handles:
- Database initialization
- Secret generation
- Service account setup
- RBAC configuration
- Network policies (if enabled)

## 🎯 Next Steps

1. Wait for pods to be ready
2. Access the web UI
3. Create admin account
4. Set up your first project
5. Start managing secrets!

## 🛠️ Troubleshooting

```bash
# Force sync if ArgoCD is stuck
kubectl patch application infisical -n argocd --type=merge -p='{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check specific pod logs
kubectl describe pod <pod-name> -n infisical

# Check service status
kubectl get endpoints -n infisical
```

This deployment follows Infisical's official documentation and best practices for Kubernetes deployment.