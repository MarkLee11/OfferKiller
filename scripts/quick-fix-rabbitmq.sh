#!/bin/bash

# Quick RabbitMQ Fix Script

echo "🔧 Quick fix for RabbitMQ hostname issue"
echo "======================================="

# Stop the current deployment script if running
echo "🛑 Stopping any running deployments..."

# Delete the failing RabbitMQ
echo "🗑️ Removing failed RabbitMQ deployment..."
helm uninstall rabbitmq-ha -n offerkiller-data || true

# Wait for pod to be deleted
echo "⏳ Waiting for RabbitMQ pod to be deleted..."
kubectl wait --for=delete pods -l app.kubernetes.io/name=rabbitmq-ha -n offerkiller-data --timeout=60s || true

# Delete PVC to clean start
echo "💾 Cleaning persistent volumes..."
kubectl delete pvc data-rabbitmq-ha-0 data-rabbitmq-ha-1 data-rabbitmq-ha-2 -n offerkiller-data --ignore-not-found=true

# Deploy with fixed configuration
echo "🚀 Deploying RabbitMQ with fixed hostname configuration..."
helm upgrade --install rabbitmq-ha infrastructure/helm/charts/rabbitmq-ha \
  -n offerkiller-data \
  -f infrastructure/helm/values/development/rabbitmq-ha.yaml \
  --wait --timeout 10m

echo "✅ RabbitMQ fix deployment completed!"

# Check status
echo "🔍 Checking RabbitMQ status..."
kubectl get pods -n offerkiller-data -l app.kubernetes.io/name=rabbitmq-ha

echo "📋 If successful, continue with Vector Database deployment:"
echo "helm upgrade --install vector-database infrastructure/helm/charts/vector-database -n offerkiller-data -f infrastructure/helm/values/development/vector-database.yaml --wait --timeout 10m"
