#!/bin/bash
set -e # Exit on error
# this script needs to be run on the k3s server node

# Get the Tailscale IP address
TAILSCALE_IP=$(tailscale ip -4)

# Check if we got an IP
if [ -z "$TAILSCALE_IP" ]; then
  echo "Error: Could not get Tailscale IP address." >&2
  exit 1
fi

# Get the k3s config and replace the server IP
sudo bat --plain /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/$TAILSCALE_IP/" | sed "s/default/k3s-server/g"
