#!/bin/bash
set -e # Exit on error

# Check for username and IP
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <user>@<server-ip>"
    exit 1
fi

# Get the remote kubeconfig
REMOTE_KUBECONFIG=$(ssh $1@$2 "/bin/bash ~/get_kubeconfig.sh")

# Check if we got a config
if [ -z "$REMOTE_KUBECONFIG" ]; then
    echo "Error: Could not get remote kubeconfig." >&2
    exit 1
fi

# Merge the new config with the existing one
KUBECONFIG=~/.kube/config:"<(echo \"$REMOTE_KUBECONFIG\")" kubectl config view --flatten > ~/.kube/config.new

# Replace the old config with the new one
mv ~/.kube/config.new ~/.kube/config

# Set the new context
kubectl config use-context k3s-server

echo "Successfully configured kubectl to use your k3s server!"

