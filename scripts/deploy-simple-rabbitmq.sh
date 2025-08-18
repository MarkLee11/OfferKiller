#!/bin/bash

# Deploy Simple RabbitMQ - Based on Official Best Practices

echo "🐰 Deploying Simple RabbitMQ (Research-Based Solution)"
echo "===================================================="

# Clean up any existing RabbitMQ
echo "🧹 Cleaning up existing RabbitMQ installations..."
helm uninstall rabbitmq-ha -n offerkiller-data 2>/dev/null || true
helm uninstall rabbitmq-simple -n offerkiller-data 2>/dev/null || true
kubectl delete pvc --all -n offerkiller-data 2>/dev/null || true

# Wait for cleanup
echo "⏳ Waiting for cleanup to complete..."
sleep 10

# Deploy simple RabbitMQ
echo "🚀 Deploying simple single-node RabbitMQ..."
helm upgrade --install rabbitmq-simple infrastructure/helm/charts/rabbitmq-simple \
  -n offerkiller-data \
  --create-namespace \
  --wait \
  --timeout 5m

# Check deployment status
echo "🔍 Checking deployment status..."
kubectl get pods -n offerkiller-data -l app.kubernetes.io/name=rabbitmq-simple

# Wait for pod to be ready
echo "⏳ Waiting for RabbitMQ to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq-simple -n offerkiller-data --timeout=300s

# Test RabbitMQ
echo "🧪 Testing RabbitMQ functionality..."
RABBITMQ_POD=$(kubectl get pods -n offerkiller-data -l app.kubernetes.io/name=rabbitmq-simple -o jsonpath='{.items[0].metadata.name}')

if [ -n "$RABBITMQ_POD" ]; then
    echo "📊 RabbitMQ Status:"
    kubectl exec -n offerkiller-data "$RABBITMQ_POD" -- rabbitmqctl status
    
    echo "👥 RabbitMQ Users:"
    kubectl exec -n offerkiller-data "$RABBITMQ_POD" -- rabbitmqctl list_users
else
    echo "❌ RabbitMQ pod not found"
    exit 1
fi

# Get access information
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")

echo ""
echo "✅ RabbitMQ Simple deployment completed!"
echo ""
echo "📝 Access Information:"
echo "   Management UI:  http://$MINIKUBE_IP:31672"
echo "   AMQP Port:      $MINIKUBE_IP:5672"
echo "   Username:       offerkilleruser"
echo "   Password:       rabbitmq123change"
echo ""
echo "🔧 Quick Test Commands:"
echo "   kubectl logs -f $RABBITMQ_POD -n offerkiller-data"
echo "   kubectl exec -it $RABBITMQ_POD -n offerkiller-data -- rabbitmqctl status"
echo ""
echo "🎉 RabbitMQ is ready for use!"
