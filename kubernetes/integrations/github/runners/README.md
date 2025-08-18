# GitHub Actions Self-Hosted Runners on K3s

This directory contains the configuration for deploying self-hosted GitHub Actions runners on your Apollo K3s cluster using the [Actions Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller).

## 🏗️ Architecture

The deployment is split into **3 separate components** for clarity and proper ordering:

```
1. RBAC Resources → 2. Controller (Helm) → 3. Runner Instances
```

## 📂 Directory Structure

```
kubernetes/integrations/github/runners/
├── README.md                     # This documentation
├── deployment/                   # Master deployment script
│   └── apply.sh                  # Deploys all 3 components in order
├── rbac/                         # Step 1: RBAC Resources
│   ├── deployment/
│   │   ├── apply.sh             # Deploy RBAC only
│   │   └── argocd.yaml          # RBAC ArgoCD Application
│   └── k8/
│       └── rbac.yaml            # ServiceAccount, Roles, Bindings
├── controller/                   # Step 2: Controller Helm Chart
│   └── deployment/
│       ├── apply.sh             # Deploy controller only
│       └── argocd.yaml          # Controller ArgoCD Application
└── instances/                    # Step 3: Runner Instances
    ├── deployment/
    │   ├── apply.sh             # Deploy runners only
    │   └── argocd.yaml          # Runners ArgoCD Application
    └── k8/
        ├── apollo-runner-deployment.yaml
        ├── apollo-runner-autoscaler.yaml
        └── github-token-secret.yaml
```

## 🚀 Quick Start (Automatic)

### Option A: Deploy Everything at Once

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token_here

# Deploy all components in correct order
cd deployment
./apply.sh deploy
```

## 🔧 Manual Deployment (Step by Step)

### Option B: Deploy Each Component Individually

This is useful for troubleshooting or understanding the deployment process.

#### Prerequisites

1. **GitHub Personal Access Token** with these permissions:
   - `repo` (if using repository-level runners)
   - `admin:org` (if using organization-level runners)
   - `workflow`

2. **Set environment variable:**
   ```bash
   export GITHUB_TOKEN=your_github_token_here
   ```

#### Step 1: Deploy RBAC Resources

```bash
cd rbac/deployment
./apply.sh deploy
```

**What this does:**
- Creates ServiceAccount: `actions-runner-controller`
- Creates ClusterRole and ClusterRoleBinding for controller permissions
- Creates Role and RoleBinding for leader election
- Creates viewer ClusterRole for read-only access

#### Step 2: Deploy Controller

```bash
cd ../controller/deployment
./apply.sh deploy
```

**What this does:**
- Installs Actions Runner Controller via Helm chart
- Creates Custom Resource Definitions (CRDs)
- Starts the controller deployment
- Sets up webhook for auto-scaling

**⏱️ Wait Time:** This step may take 2-3 minutes for the Helm chart to deploy.

#### Step 3: Deploy Runner Instances

```bash
cd ../instances/deployment
./apply.sh deploy
```

**What this does:**
- Creates RunnerDeployment (defines runner specs)
- Creates HorizontalRunnerAutoscaler (auto-scaling rules)
- Starts actual runner pods

## 📊 Monitoring and Status

### Check Overall Status

```bash
# Check all ArgoCD applications
kubectl get applications -n argocd | grep github

# Check all resources in github-runners namespace
kubectl get all -n github-runners

# Check runners specifically
kubectl get runners -n github-runners
kubectl get runnerdeployments -n github-runners
kubectl get hra -n github-runners
```

### Check Individual Components

```bash
# RBAC status
cd rbac/deployment && ./apply.sh status

# Controller status
cd controller/deployment && ./apply.sh status

# Runners status
cd instances/deployment && ./apply.sh status
```

### Logs and Troubleshooting

```bash
# Controller logs
kubectl logs -n github-runners deployment/gh-actions-runner-controller

# Runner logs
kubectl logs -n github-runners -l app=apollo-github-runners

# ArgoCD application status
kubectl describe application github-actions-rbac -n argocd
kubectl describe application github-actions-controller -n argocd
kubectl describe application github-actions-runners -n argocd
```

## 🏷️ Runner Configuration

### Labels

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

## 🔧 Resource Usage

Each runner pod requests:
- **CPU**: 500m (0.5 cores)
- **Memory**: 1Gi
- **Limits**: 2 CPU cores, 4Gi memory
- **Storage**: 10Gi persistent work directory

## 🛡️ Security Features

- **Ephemeral runners**: Fresh environment for each job
- **Limited privileges**: Runs as non-root user
- **Resource limits**: Prevents resource exhaustion
- **Secret management**: GitHub token stored securely
- **Network isolation**: Runs in dedicated namespace
- **RBAC**: Proper role-based access control

## 🗑️ Cleanup

### Remove Everything

```bash
cd deployment
./apply.sh remove
```

### Remove Individual Components

```bash
# Remove in reverse order
cd instances/deployment && ./apply.sh remove
cd ../controller/deployment && ./apply.sh remove
cd ../rbac/deployment && ./apply.sh remove
```

## ⚠️ Troubleshooting

### Common Issues

1. **"Resource not found" errors**
   - Ensure you deployed components in the correct order (RBAC → Controller → Runners)
   - Check if CRDs are installed: `kubectl get crd | grep actions.summerwind.dev`

2. **Runners not appearing in GitHub**
   - Verify GitHub token: `kubectl get secret controller-manager -n github-runners -o yaml`
   - Check controller logs: `kubectl logs -n github-runners deployment/gh-actions-runner-controller`

3. **Pods stuck in pending**
   - Check node resources: `kubectl describe nodes`
   - Verify storage class: `kubectl get storageclass`

4. **Permission errors**
   - Verify RBAC resources: `kubectl get clusterrole actions-runner-controller`
   - Check ArgoCD project permissions for "integrations"

### Manual Scaling

```bash
# Scale runners manually
kubectl scale runnerdeployment apollo-github-runners --replicas=5 -n github-runners

# Check autoscaler status
kubectl describe hra apollo-runner-autoscaler -n github-runners
```

## 🔗 Integration with Existing Services

The runners can access other services in your cluster:
- **Harbor**: `harbor-core.registry.svc.cluster.local`
- **Vault**: `vault.vault.svc.cluster.local`
- **ArgoCD**: `argocd-server.argocd.svc.cluster.local`

## 📈 Port Information

Add to your `PORT_MAPPINGS.md`:

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Runner Controller Metrics** | 8080 | Internal only | Prometheus metrics |
| **Runner Webhook** | 9443 | Internal only | GitHub webhook receiver |

## 🔄 GitOps Integration

All components are managed via ArgoCD for proper GitOps workflow:
- **Applications**: 3 separate ArgoCD applications
- **Project**: `integrations`
- **Sync Policy**: Automated with self-healing
- **Repository**: Uses your `apollo-iac` repository

## 📋 Deployment Order Summary

| Step | Component | Description | Command |
|------|-----------|-------------|---------|
| 1 | RBAC | ServiceAccount, Roles, Bindings | `rbac/deployment/apply.sh` |
| 2 | Controller | Helm chart, CRDs, Controller pods | `controller/deployment/apply.sh` |
| 3 | Runners | RunnerDeployment, Autoscaler, Runner pods | `instances/deployment/apply.sh` |

**⚠️ Important:** Always deploy in this order. Each step depends on the previous one.