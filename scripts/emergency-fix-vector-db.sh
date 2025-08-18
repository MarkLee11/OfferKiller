#!/bin/bash

# Emergency Fix for Vector Database Deployment Issues
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}🚀 $1${NC}"; }
print_info() { echo -e "${CYAN}📁 $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

NAMESPACE="offerkiller-data"

print_status "Emergency Fix for Vector Database"
echo "================================="

# Step 1: Force cleanup everything
force_cleanup() {
    print_info "Step 1: Force cleanup all vector database resources..."
    
    # Delete helm releases
    helm uninstall vector-database -n "$NAMESPACE" 2>/dev/null || true
    helm uninstall vector-db -n "$NAMESPACE" 2>/dev/null || true
    
    # Delete all potential resources
    kubectl delete deployment,service,configmap,pvc,pod -l app.kubernetes.io/name=vector-database -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    kubectl delete deployment,service,configmap,pvc,pod -l app.kubernetes.io/name=vector-db -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    
    # Delete by specific names
    kubectl delete deployment vector-database -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete deployment vector-db -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete service vector-database -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete service vector-db -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete configmap vector-database-config -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete configmap vector-db-config -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete pvc vector-database-data -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete pvc vector-db-data -n "$NAMESPACE" 2>/dev/null || true
    
    # Wait for cleanup
    sleep 15
    print_info "Cleanup completed"
}

# Step 2: Create super simple deployment
create_simple_deployment() {
    print_info "Step 2: Creating super simple deployment..."
    
    # Create a direct Kubernetes deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vector-database
  namespace: $NAMESPACE
  labels:
    app: vector-database
    app.kubernetes.io/name: vector-database
    app.kubernetes.io/instance: vector-database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vector-database
      app.kubernetes.io/name: vector-database
      app.kubernetes.io/instance: vector-database
  template:
    metadata:
      labels:
        app: vector-database
        app.kubernetes.io/name: vector-database
        app.kubernetes.io/instance: vector-database
    spec:
      containers:
      - name: chromadb
        image: chromadb/chroma:0.4.12
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: IS_PERSISTENT
          value: "TRUE"
        - name: PERSIST_DIRECTORY
          value: "/chroma/chroma"
        - name: ANONYMIZED_TELEMETRY
          value: "FALSE"
        command: ["uvicorn"]
        args: ["chromadb.app:app", "--host", "0.0.0.0", "--port", "8000", "--log-level", "info"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /api/v1/heartbeat
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /api/v1/heartbeat
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        volumeMounts:
        - name: data
          mountPath: /chroma/chroma
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: vector-database
  namespace: $NAMESPACE
  labels:
    app: vector-database
    app.kubernetes.io/name: vector-database
    app.kubernetes.io/instance: vector-database
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: vector-database
    app.kubernetes.io/name: vector-database
    app.kubernetes.io/instance: vector-database
---
apiVersion: v1
kind: Service
metadata:
  name: vector-database-nodeport
  namespace: $NAMESPACE
  labels:
    app: vector-database
    app.kubernetes.io/name: vector-database
spec:
  type: NodePort
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30800
    protocol: TCP
    name: http
  selector:
    app: vector-database
    app.kubernetes.io/name: vector-database
    app.kubernetes.io/instance: vector-database
EOF
    
    print_info "Simple deployment created"
}

# Step 3: Wait for readiness
wait_for_ready() {
    print_info "Step 3: Waiting for deployment to be ready..."
    
    # Wait for deployment to be available
    kubectl wait --for=condition=available deployment/vector-database -n "$NAMESPACE" --timeout=300s
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=vector-database -n "$NAMESPACE" --timeout=300s
    
    print_info "Deployment is ready"
}

# Step 4: Test the deployment
test_simple_deployment() {
    print_info "Step 4: Testing the deployment..."
    
    # Get pod name
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=vector-database -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod_name" ]; then
        print_error "No pods found"
        return 1
    fi
    
    print_info "Testing pod: $pod_name"
    
    # Wait a bit for ChromaDB to fully start
    sleep 30
    
    # Test heartbeat
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/heartbeat; then
        print_status "✅ Vector Database is responding!"
        echo
    else
        print_error "Vector Database is not responding"
        print_info "Pod logs:"
        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=20
        return 1
    fi
    
    # Test collections endpoint
    print_info "Testing collections endpoint..."
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/collections; then
        print_status "✅ Collections endpoint working!"
        echo
    else
        print_warning "Collections endpoint not responding (might be normal for new installation)"
    fi
}

# Step 5: Show status
show_final_status() {
    print_status "Final Status:"
    echo "============="
    
    kubectl get pods -n "$NAMESPACE" -l app=vector-database
    kubectl get svc -n "$NAMESPACE" -l app=vector-database
    
    echo
    print_info "Access Information:"
    
    if command -v minikube &>/dev/null; then
        local minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
        echo "  External: http://$minikube_ip:30800/api/v1/heartbeat"
        echo "  Test: curl http://$minikube_ip:30800/api/v1/heartbeat"
    fi
    
    echo "  Internal: vector-database.offerkiller-data.svc.cluster.local:8000"
    echo "  Port Forward: kubectl port-forward -n offerkiller-data svc/vector-database 8000:8000"
    
    echo
    print_info "Useful Commands:"
    echo "  kubectl logs -f deployment/vector-database -n offerkiller-data"
    echo "  kubectl exec -it deployment/vector-database -n offerkiller-data -- /bin/bash"
    echo "  kubectl describe pod -l app=vector-database -n offerkiller-data"
}

# Main execution
main() {
    # Navigate to project root
    cd "$(dirname "$0")/.."
    
    case "${1:-fix}" in
        "fix")
            force_cleanup
            create_simple_deployment
            wait_for_ready
            test_simple_deployment
            show_final_status
            print_status "✅ Emergency fix completed!"
            ;;
        "test")
            test_simple_deployment
            ;;
        "clean")
            force_cleanup
            print_status "✅ Emergency cleanup completed!"
            ;;
        "status")
            show_final_status
            ;;
        *)
            echo "Usage: $0 [fix|test|clean|status]"
            echo "  fix:    Force cleanup and create simple deployment (default)"
            echo "  test:   Test existing deployment"
            echo "  clean:  Force cleanup everything"
            echo "  status: Show current status"
            exit 1
            ;;
    esac
}

main "$@"