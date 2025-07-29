# apollo-iac
Homeserver apollo headless ubuntu infrastructure automation

## Quick Setup

Run this on your fresh Ubuntu headless server to configure SSH access and Tailscale:

```bash
wget https://raw.githubusercontent.com/your-username/apollo-iac/main/setup.sh
chmod +x setup.sh
./setup.sh
```

Or if you have this repository cloned:

```bash
chmod +x setup.sh
./setup.sh
```

## What the script does

- Updates system packages
- Installs zsh shell and custom dotfiles configuration
- Installs and configures SSH with security hardening
- Sets up UFW firewall with proper rules
- Configures fail2ban for SSH protection
- Installs Tailscale VPN client with SSH integration
- Installs git for repository management
- Installs and configures k3s Kubernetes cluster

## Post-setup steps

1. Run `sudo tailscale up --ssh` to connect and enable SSH
2. Authenticate via the Tailscale web interface when prompted
3. Secure SSH to Tailscale only:
   ```bash
   sudo ufw allow in on tailscale0 to any port 22
   sudo ufw delete allow ssh
   ```
4. Test k3s cluster: `kubectl get nodes`

## Tailscale SSH Benefits

- **No SSH key management** - Tailscale handles authentication automatically
- **Secure by default** - Only devices in your tailnet can connect
- **Easy automation** - Script SSH connections without managing keys
- **ACL support** - Control which devices can SSH to which servers via Tailscale admin

## SSH Connection Examples

```bash
# From any device in your tailnet
ssh user@server-hostname
ssh user@100.x.x.x  # Tailscale IP address
```

## k3s Kubernetes Cluster

The script installs a single-node k3s cluster that's ready for workloads.

### Accessing the cluster locally

```bash
# On the server
kubectl get nodes
kubectl get pods -A
```

### Accessing the cluster from remote machines

1. **Copy the kubeconfig file** from the server:
   ```bash
   # On your local machine
   scp user@server-hostname:/etc/rancher/k3s/k3s.yaml ~/.kube/config-apollo
   ```

2. **Update the server address** in the config file:
   ```bash
   # Edit ~/.kube/config-apollo
   # Change server: https://127.0.0.1:6443
   # To:     server: https://TAILSCALE-IP:6443
   ```

3. **Use the config**:
   ```bash
   # Set as default
   export KUBECONFIG=~/.kube/config-apollo
   
   # Or use with specific commands
   kubectl --kubeconfig ~/.kube/config-apollo get nodes
   ```

### k3s Features

- **Lightweight** - Perfect for homelab and edge computing
- **Batteries included** - Traefik ingress, CoreDNS, local storage
- **Easy management** - Single binary installation
- **Secure by default** - Runs only on Tailscale network

### Common k3s commands

```bash
# Check cluster status
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# Check k3s logs
sudo journalctl -u k3s -f

# Restart k3s
sudo systemctl restart k3s
```
