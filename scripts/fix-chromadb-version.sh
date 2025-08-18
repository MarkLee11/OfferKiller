#!/bin/bash

# ChromaDB Version Fix Script
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

print_status "ChromaDB Version Fix"
echo "===================="

# Step 1: Complete cleanup
cleanup_all() {
    print_info "Step 1: Complete cleanup..."
    
    # Delete all vector database resources
    kubectl delete deployment vector-database -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    kubectl delete service vector-database -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    kubectl delete service vector-database-nodeport -n "$NAMESPACE" --force --grace-period=0 2>/dev/null || true
    
    # Wait for cleanup
    sleep 10
    print_info "Cleanup completed"
}

# Step 2: Deploy with stable ChromaDB version
deploy_stable_chromadb() {
    print_info "Step 2: Deploying stable ChromaDB version..."
    
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
        args: 
        - "chromadb.app:app"
        - "--host"
        - "0.0.0.0"
        - "--port"
        - "8000"
        - "--log-level"
        - "info"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/v1/heartbeat
            port: 8000
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /api/v1/heartbeat
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 5
          failureThreshold: 3
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
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: vector-database
---
apiVersion: v1
kind: Service
metadata:
  name: vector-database-nodeport
  namespace: $NAMESPACE
  labels:
    app: vector-database
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
EOF
    
    print_info "Stable ChromaDB deployment created"
}

# Step 3: Wait and monitor startup
monitor_startup() {
    print_info "Step 3: Monitoring startup (this may take 2-3 minutes)..."
    
    # Wait for deployment to be created
    sleep 30
    
    # Monitor pod status
    local count=0
    local max_wait=240  # 4 minutes
    
    while [ $count -lt $max_wait ]; do
        local pod_status=$(kubectl get pods -n "$NAMESPACE" -l app=vector-database -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        
        print_info "Status: $pod_status (${count}s/${max_wait}s)"
        
        if [ "$pod_status" = "Running" ]; then
            print_success "✅ Pod is running: $pod_name"
            break
        elif [ "$pod_status" = "CrashLoopBackOff" ] || [ "$pod_status" = "Error" ]; then
            print_error "Pod failed. Checking logs..."
            if [ -n "$pod_name" ]; then
                kubectl logs "$pod_name" -n "$NAMESPACE" --tail=10
            fi
            return 1
        fi
        
        sleep 15
        count=$((count + 15))
    done
    
    if [ $count -ge $max_wait ]; then
        print_error "Timeout waiting for pod to start"
        return 1
    fi
}

# Step 4: Test the service
test_service() {
    print_info "Step 4: Testing ChromaDB service..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_error "No pod found"
        return 1
    fi
    
    print_info "Testing pod: $pod_name"
    
    # Wait for ChromaDB to fully initialize
    print_info "Waiting for ChromaDB to initialize..."
    sleep 60
    
    # Test heartbeat endpoint
    print_info "Testing heartbeat endpoint..."
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -f http://localhost:8000/api/v1/heartbeat >/dev/null 2>&1; then
        print_status "✅ Heartbeat test passed!"
        
        # Show the actual response
        local response=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/heartbeat 2>/dev/null)
        echo "Response: $response"
        
    else
        print_warning "Heartbeat test failed, but let's check if the service is starting..."
        kubectl logs "$pod_name" -n "$NAMESPACE" --tail=20
        return 1
    fi
    
    # Test collections endpoint
    print_info "Testing collections endpoint..."
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -f http://localhost:8000/api/v1/collections >/dev/null 2>&1; then
        print_status "✅ Collections endpoint working!"
        local collections=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/collections 2>/dev/null)
        echo "Collections: $collections"
    else
        print_info "Collections endpoint not ready yet (normal for new installation)"
    fi
}

# Step 5: Show final status
show_final_status() {
    print_status "Final Status:"
    echo "============="
    
    kubectl get pods -n "$NAMESPACE" -l app=vector-database -o wide
    kubectl get svc -n "$NAMESPACE" -l app=vector-database
    
    echo
    print_info "Access Information:"
    
    if command -v minikube &>/dev/null; then
        local minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
        echo "  External API: http://$minikube_ip:30800"
        echo "  Heartbeat: http://$minikube_ip:30800/api/v1/heartbeat"
        echo "  Collections: http://$minikube_ip:30800/api/v1/collections"
        
        echo
        print_info "Quick Test:"
        echo "  curl http://$minikube_ip:30800/api/v1/heartbeat"
    fi
    
    echo "  Internal: vector-database.offerkiller-data.svc.cluster.local:8000"
    echo "  Port Forward: kubectl port-forward -n offerkiller-data svc/vector-database 8000:8000"
    
    echo
    print_info "Monitoring:"
    echo "  kubectl logs -f deployment/vector-database -n offerkiller-data"
    echo "  kubectl get pods -n offerkiller-data -l app=vector-database -w"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Main execution
main() {
    case "${1:-fix}" in
        "fix")
            cleanup_all
            deploy_stable_chromadb
            monitor_startup
            test_service
            show_final_status
            print_status "✅ ChromaDB version fix completed!"
            ;;
        "test")
            test_service
            ;;
        "status")
            show_final_status
            ;;
        "logs")
            local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=vector-database -o jsonpath='{.items[0].metadata.name}')
            if [ -n "$pod_name" ]; then
                kubectl logs -f "$pod_name" -n "$NAMESPACE"
            else
                print_error "No pod found"
            fi
            ;;
        *)
            echo "Usage: $0 [fix|test|status|logs]"
            echo "  fix:    Fix ChromaDB version issues (default)"
            echo "  test:   Test current deployment"
            echo "  status: Show current status"
            echo "  logs:   Show pod logs"
            exit 1
            ;;
    esac
}

main "$@"