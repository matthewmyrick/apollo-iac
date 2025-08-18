# GitHub Actions Self-Hosted Runners on K3s

This directory contains the configuration for deploying self-hosted GitHub Actions runners on your Apollo K3s cluster using the [Actions Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller).

## Overview

The setup includes:
- **Runner Controller**: Manages the lifecycle of GitHub runners
- **Runner Deployment**: Defines runner specifications and scaling
- **Horizontal Autoscaler**: Automatically scales runners based on demand
- **Security**: Proper RBAC and secrets management

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub.com    │    │  Runner Controller│    │ Runner Pods     │
│                 │◄──►│  (Coordinator)    │◄──►│ (Actual Jobs)   │
│ Workflow Queue  │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Quick Start

### 1. Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Create a new token with these permissions:
   - `repo` (if using repository-level runners)
   - `admin:org` (if using organization-level runners)
   - `workflow`

### 2. Set Environment Variable

```bash
export GITHUB_TOKEN=your_github_token_here
```

### 3. Deploy Runners

```bash
# Deploy everything
./apply.sh deploy

# Check status
./apply.sh status

# Clean up (if needed)
./apply.sh clean
```

## Configuration

### Runner Labels

Your runners will be available with these labels:
- `apollo` - Custom label for your infrastructure
- `self-hosted` - Standard GitHub label
- `k3s` - Indicates K3s environment
- `linux` - Operating system
- `x64` - Architecture

### Using in Workflows

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, apollo]
    steps:
      - uses: actions/checkout@v4
      - name: Build project
        run: |
          echo "Building on Apollo K3s runners!"
```

### Scaling Configuration

- **Default replicas**: 2 runners
- **Auto-scaling**: 1-10 runners based on demand
- **Scale up**: When 75% of runners are busy
- **Scale down**: When only 25% are busy
- **Ephemeral**: Runners are recreated after each job for security

## Resource Usage

Each runner pod requests:
- **CPU**: 500m (0.5 cores)
- **Memory**: 1Gi
- **Limits**: 2 CPU cores, 4Gi memory
- **Storage**: 10Gi persistent work directory

## Security Features

- **Ephemeral runners**: Fresh environment for each job
- **Limited privileges**: Runs as non-root user
- **Resource limits**: Prevents resource exhaustion
- **Secret management**: GitHub token stored securely
- **Network isolation**: Runs in dedicated namespace

## Monitoring

### Check Runner Status
```bash
# View all runners
kubectl get runners -n github-runners

# View runner deployments
kubectl get runnerdeployments -n github-runners

# View autoscaler status
kubectl get hra -n github-runners

# View runner logs
kubectl logs -n github-runners -l app=apollo-github-runners
```

### ArgoCD Integration
The runners are deployed via ArgoCD for GitOps management:
- **Application**: `github-actions-runner-controller`
- **Namespace**: `github-runners`
- **Sync Policy**: Automated with self-healing

## File Structure

```
github-runners/
├── README.md                          # This documentation
├── apply.sh                           # Deployment script
├── argocd.yaml                        # ArgoCD application for controller
├── runners/
│   ├── apollo-runner-deployment.yaml  # Runner deployment spec
│   └── apollo-runner-autoscaler.yaml  # Horizontal autoscaler
└── secrets/
    └── github-token-secret.yaml       # Secret template
```

## Customization

### Repository vs Organization Runners

**Repository-level** (current setup):
```yaml
spec:
  template:
    spec:
      repository: matthewmyrick/apollo-iac
```

**Organization-level**:
```yaml
spec:
  template:
    spec:
      organization: your-org-name
```

### Custom Runner Image

```yaml
spec:
  template:
    spec:
      image: your-registry/custom-runner:latest
      # Add custom tools, dependencies, etc.
```

### Resource Adjustments

```yaml
spec:
  template:
    spec:
      resources:
        requests:
          cpu: 1
          memory: 2Gi
        limits:
          cpu: 4
          memory: 8Gi
```

## Troubleshooting

### Common Issues

1. **Runners not appearing in GitHub**
   ```bash
   # Check controller logs
   kubectl logs -n github-runners deployment/actions-runner-controller
   
   # Verify GitHub token
   kubectl get secret controller-manager -n github-runners -o yaml
   ```

2. **Pods stuck in pending**
   ```bash
   # Check node resources
   kubectl describe nodes
   
   # Check storage class
   kubectl get storageclass
   ```

3. **Authentication errors**
   ```bash
   # Recreate token secret
   kubectl delete secret controller-manager -n github-runners
   export GITHUB_TOKEN=new_token
   ./apply.sh deploy
   ```

### Scaling Issues

```bash
# Manual scaling
kubectl scale runnerdeployment apollo-github-runners --replicas=5 -n github-runners

# Check autoscaler
kubectl describe hra apollo-runner-autoscaler -n github-runners
```

## Integration with Existing Services

The runners can access other services in your cluster:
- **Harbor**: `harbor-core.registry.svc.cluster.local`
- **Vault**: `vault.vault.svc.cluster.local`
- **ArgoCD**: `argocd-server.argocd.svc.cluster.local`

## Security Considerations

- Runners have Docker socket access (required for container builds)
- Consider using rootless Docker for enhanced security
- Monitor runner resource usage to prevent cluster impact
- Regularly rotate GitHub tokens
- Use secrets management for sensitive data in workflows

## Port Information

The GitHub runner controller uses these ports:
- **Metrics**: 8080
- **Webhook**: 9443 (for advanced scaling)
- **Health**: 8081

Add to your `PORT_MAPPINGS.md`:
| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Runner Controller Metrics** | 8080 | Internal only | Prometheus metrics |
| **Runner Webhook** | 9443 | Internal only | GitHub webhook receiver |