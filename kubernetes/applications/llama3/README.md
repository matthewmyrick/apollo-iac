# Llama3 Deployment on Kubernetes

This deployment runs Llama3 using Ollama on Kubernetes with NodePort exposure.

## Architecture

- **Ollama**: Open-source LLM runner that provides a simple API
- **Model**: Llama3.2:3b (3 billion parameter model, ~2GB download)
- **Storage**: 20Gi PVC for model storage
- **Service**: NodePort on port 30434

## Deployment Commands

### Via ArgoCD (Recommended)
```bash
# Deploy using ArgoCD
kubectl apply -f kubernetes/applications/llama3/deployment/argocd.yaml

# Or use the apply script
./kubernetes/applications/llama3/deployment/apply.sh
```

### Direct Deployment
```bash
# If ArgoCD is not available, deploy directly
kubectl apply -f kubernetes/applications/llama3/deployment/namespace.yaml
kubectl apply -f kubernetes/applications/llama3/deployment/deployment.yaml
kubectl apply -f kubernetes/applications/llama3/deployment/service.yaml

# Or use the apply script (auto-detects method)
./kubernetes/applications/llama3/deployment/apply.sh
```

## Usage Examples

### Check Model Status
```bash
curl http://localhost:30434/api/tags
```

### Generate Text
```bash
curl http://localhost:30434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Write a haiku about kubernetes",
  "stream": false
}'
```

### Chat Completion
```bash
curl http://localhost:30434/api/chat -d '{
  "model": "llama3.2:3b",
  "messages": [
    {"role": "user", "content": "What is Kubernetes?"}
  ]
}'
```

### Streaming Response
```bash
curl http://localhost:30434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Explain quantum computing",
  "stream": true
}'
```

## Access Points

- **Internal**: `http://ollama-service.llama3.svc.cluster.local:11434`
- **NodePort**: `http://<node-ip>:30434`
- **Local**: `http://localhost:30434` (if on the node)

## Resource Requirements

- **Requests**: 4Gi memory, 2 CPU cores
- **Limits**: 8Gi memory, 4 CPU cores
- **Storage**: 20Gi for model storage

## Monitoring

```bash
# Check pod status
kubectl get pods -n llama3

# View logs
kubectl logs -n llama3 -l app=ollama

# Check resource usage
kubectl top pods -n llama3
```

## Troubleshooting

### Model Not Loading
```bash
# Exec into pod and manually pull model
kubectl exec -it -n llama3 deployment/ollama-llama3 -- ollama pull llama3.2:3b
```

### Check Available Models
```bash
kubectl exec -n llama3 deployment/ollama-llama3 -- ollama list
```

### Performance Issues
- Increase resource limits in deployment.yaml
- Consider using a smaller model (llama3.2:1b)
- Enable GPU support if available

## Alternative Models

To use different models, update the deployment.yaml:
- `llama3.2:1b` - Smaller, faster (1B parameters)
- `llama3.2:3b` - Default (3B parameters)
- `mistral:7b` - Larger, more capable
- `phi3:mini` - Microsoft's small model