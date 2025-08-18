#!/bin/bash

# OfferKiller Cluster Restart and Recovery Script

echo "🚀 OfferKiller Cluster Restart and Recovery"
echo "=========================================="

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed"
    exit 1
fi

# Start minikube
echo "🔧 Starting minikube cluster..."
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50gb \
  --kubernetes-version=v1.28.0

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Enable addons
echo "🔌 Enabling minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# Check cluster status
echo "🔍 Checking cluster status..."
kubectl cluster-info
kubectl get nodes

# Check if foundational services exist
echo "🔍 Checking foundational services..."
if ! kubectl get namespace offerkiller-system &>/dev/null; then
    echo "📦 Foundational services not found, deploying..."
    if [ -f "./scripts/deploy-k8s-foundation.sh" ]; then
        ./scripts/deploy-k8s-foundation.sh
    else
        echo "⚠️ Foundation deployment script not found"
        echo "You may need to deploy foundational services manually"
    fi
else
    echo "✅ Foundational services namespace exists"
fi

# Deploy data layer services
echo "📦 Deploying data layer services..."
if [ -f "./scripts/deploy-data-layer.sh" ]; then
    ./scripts/deploy-data-layer.sh --environment development
else
    echo "❌ Data layer deployment script not found"
    exit 1
fi

echo "✅ Cluster recovery completed!"
echo ""
echo "📋 Next steps:"
echo "1. Monitor pods: kubectl get pods -A"
echo "2. Check service status: ./scripts/health-check-data-layer.sh"
echo "3. Access services via: minikube ip"
echo ""
echo "🌐 Cluster IP: $(minikube ip)"
