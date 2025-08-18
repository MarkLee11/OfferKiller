#!/bin/bash

# Quick status check script

echo "🔍 OfferKiller Cluster Status"
echo "============================"

# Cluster info
echo "🌐 Cluster Info:"
kubectl cluster-info

echo ""
echo "📊 Node Status:"
kubectl get nodes

echo ""
echo "📦 All Namespaces:"
kubectl get namespaces

echo ""
echo "🏃 All Pods:"
kubectl get pods -A

echo ""
echo "🌐 All Services:"
kubectl get svc -A

echo ""
echo "💾 Persistent Volumes:"
kubectl get pv,pvc -A

echo ""
echo "🔗 Minikube IP:"
minikube ip 2>/dev/null || echo "Minikube not running"

echo ""
echo "✅ Status check completed!"
