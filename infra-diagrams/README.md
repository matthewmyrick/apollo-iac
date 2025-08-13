# Infrastructure Request Flow Diagrams

Clean, simple diagrams showing how requests flow through your infrastructure stack.

## What This Shows

### Request Flow Diagram (`request_flow.png`)
Shows the complete journey of a web request from user to your Hello World app:

1. **User** types `www.matthewjmyrick.com` in browser
2. **GoDaddy DNS** resolves domain to Tailscale IP
3. **Tailscale Funnel** receives public HTTPS request
4. **Ubuntu Server** (private tailnet IP: 100.96.78.104)
5. **K3s Ingress** routes request via Tailscale operator
6. **Hello World Pod** serves response
7. **Response flows back** to user

### Security Model Diagram (`security_model.png`)
- Only the specific Hello World app is exposed publicly
- SSH, K8s API, and other services remain private
- Tailscale acts as secure reverse proxy
- Everything encrypted end-to-end

## How to Generate

```bash
# Activate virtual environment
source venv/bin/activate

# Generate diagrams
python request_flow.py
```

## Output Files

- `diagrams/request_flow.png` - Main request flow diagram
- `diagrams/security_model.png` - Security model explanation

## Network Architecture

```
Internet → GoDaddy DNS → Tailscale Funnel → Private Server
                                                ↓
                                          K3s Cluster
                                                ↓
                                          Hello World Pod
```

**Security Zones:**
- **Public**: Only www.matthewjmyrick.com on port 443
- **Private**: SSH, K8s API, all other services (Tailscale only)