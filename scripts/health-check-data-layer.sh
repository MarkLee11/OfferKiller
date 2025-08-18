#!/bin/bash

# OfferKiller Data Layer Health Check Script

echo "🔍 OfferKiller Data Layer Health Check"
echo "======================================"

# Check namespace
echo "📦 Checking namespace..."
kubectl get namespace offerkiller-data

echo ""
echo "📋 Pod Status:"
kubectl get pods -n offerkiller-data -o wide

echo ""
echo "🌐 Service Status:"
kubectl get svc -n offerkiller-data

echo ""
echo "💾 Storage Status:"
kubectl get pvc -n offerkiller-data

echo ""
echo "🔴 Testing Redis Cluster..."
redis_result=$(kubectl exec -n offerkiller-data redis-cluster-0 -- redis-cli ping 2>/dev/null)
if [ "$redis_result" = "PONG" ]; then
    echo "✅ Redis is responding"
    echo "📊 Redis cluster info:"
    kubectl exec -n offerkiller-data redis-cluster-0 -- redis-cli cluster nodes | head -3
else
    echo "❌ Redis is not responding"
fi

echo ""
echo "🐰 Testing RabbitMQ Cluster..."
rabbitmq_result=$(kubectl exec -n offerkiller-data rabbitmq-ha-0 -- rabbitmqctl status --quiet 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ RabbitMQ is operational"
    echo "📊 RabbitMQ cluster status:"
    kubectl exec -n offerkiller-data rabbitmq-ha-0 -- rabbitmqctl cluster_status --quiet | grep "Running nodes"
else
    echo "❌ RabbitMQ has issues"
fi

echo ""
echo "🧠 Testing Vector Database..."
# Find the actual pod name for vector database
vector_pod=$(kubectl get pods -n offerkiller-data -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$vector_pod" ]; then
    vector_result=$(kubectl exec -n offerkiller-data "$vector_pod" -- curl -s http://localhost:8000/api/v1/heartbeat 2>/dev/null)
    if [ -n "$vector_result" ]; then
        echo "✅ Vector Database is responding"
        echo "📊 Response: $vector_result"
    else
        echo "❌ Vector Database is not responding"
    fi
else
    echo "❌ Vector Database pod not found"
fi

echo ""
echo "📊 Resource Usage:"
kubectl top pods -n offerkiller-data 2>/dev/null || echo "Metrics server not available"

echo ""
echo "🔍 Recent Events:"
kubectl get events -n offerkiller-data --sort-by=.metadata.creationTimestamp | tail -10

echo ""
echo "✅ Health check completed!"
