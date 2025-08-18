#!/bin/bash

# Quick fix script for RabbitMQ deployment issues

echo "🔧 Fixing RabbitMQ deployment issues..."

# Delete the failed RabbitMQ deployment
echo "🗑️ Removing failed RabbitMQ deployment..."
helm uninstall rabbitmq-ha -n offerkiller-data || true

# Wait for pods to be deleted
echo "⏳ Waiting for pods to be deleted..."
kubectl wait --for=delete pods -l app.kubernetes.io/name=rabbitmq-ha -n offerkiller-data --timeout=60s || true

# Delete PVC to start fresh
echo "💾 Cleaning up persistent volumes..."
kubectl delete pvc data-rabbitmq-ha-0 -n offerkiller-data --ignore-not-found=true

# Redeploy RabbitMQ with fixed configuration
echo "🚀 Redeploying RabbitMQ with fixed configuration..."
helm upgrade --install rabbitmq-ha infrastructure/helm/charts/rabbitmq-ha \
  -n offerkiller-data \
  -f infrastructure/helm/values/development/rabbitmq-ha.yaml \
  --wait --timeout 10m

echo "✅ RabbitMQ fix completed!"
