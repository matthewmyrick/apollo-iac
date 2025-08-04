#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# The full path to the get_kubeconfig.sh script on the remote Ubuntu server.
REMOTE_SCRIPT_PATH="/home/matthewmyrick/github/matthewmyrick/apollo-iac/k8s/connect/get_kubeconfig.sh"

# Check if the user provided the SSH target as an argument.
if [ -z "$1" ]; then
    echo "Usage: $0 <user@server-ip>"
    echo "Example: $0 matthewmyrick@100.96.78.104"
    exit 1
fi

SSH_TARGET=$1

echo "--> Connecting to $SSH_TARGET to retrieve kubeconfig..."

# SSH to the remote server, execute the script, and capture the output.
REMOTE_KUBECONFIG=$(ssh "$SSH_TARGET" "bash $REMOTE_SCRIPT_PATH")

# Verify that we actually got some output.
if [ -z "$REMOTE_KUBECONFIG" ]; then
    echo "Error: Failed to retrieve kubeconfig from the remote server." >&2
    echo "Please check your SSH connection and ensure the script exists at the specified path on the server." >&2
    exit 1
fi

echo "--> Merging retrieved config into your local ~/.kube/config..."

# Create a backup of the current kubeconfig file.
cp ~/.kube/config ~/.kube/config.bak-$(date +%F-%T)

# Safely merge the new config with the existing one by creating a new file.
KUBECONFIG=~/.kube/config:"<(echo \"$REMOTE_KUBECONFIG\")" kubectl config view --flatten > ~/.kube/config.new

# Replace the old config with the new, merged config.
mv ~/.kube/config.new ~/.kube/config

echo "--> Setting kubectl context to 'k3s-server'..."
kubectl config use-context k3s-server

echo ""
echo "✅ Success! Your kubectl is now configured to connect to the remote k3s cluster."
echo "A backup of your previous configuration has been saved with a timestamp in ~/.kube/"
echo "You can verify the connection by running: kubectl get nodes"

