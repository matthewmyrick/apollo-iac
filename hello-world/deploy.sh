#!/bin/bash

set -e

echo "==========================================="
echo "Deploying Hello World App"
echo "==========================================="

# Build and run the Docker container
echo "Building Docker image..."
docker build -t hello-world-app .

echo "Stopping existing container if running..."
docker stop hello-world-app 2>/dev/null || true
docker rm hello-world-app 2>/dev/null || true

echo "Starting new container..."
docker run -d --name hello-world-app -p 8080:80 hello-world-app

echo "Container started on port 8080"
echo "Testing local access..."
sleep 2
curl -s http://localhost:8080 | head -5

echo ""
echo "==========================================="
echo "Next steps:"
echo "==========================================="
echo "1. Run: sudo tailscale serve --https=443 --set-path=/hello http://localhost:8080"
echo "2. Run: sudo tailscale serve --bg --https=443 --hostname=matthewmyrick.com http://localhost:8080"
echo "3. Configure your GoDaddy DNS to point matthewmyrick.com to Tailscale's public IP"
echo ""
echo "The app is now running locally on port 8080"