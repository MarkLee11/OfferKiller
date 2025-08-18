#!/bin/bash

# Quick Fix Script for Vector Database Issues
# This script addresses common vector database deployment problems

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
RELEASE_NAME="vector-database"

print_status "Quick Fix for Vector Database Issues"
echo "===================================="

# Step 1: Clean up any existing broken deployments
cleanup_existing() {
    print_info "Step 1: Cleaning up existing deployments..."
    
    # Uninstall helm release if it exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_warning "Removing existing Helm release..."
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
    fi
    
    # Delete any leftover resources
    kubectl delete deployment vector-database -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete service vector-database -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete service vector-database-nodeport -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete configmap vector-database-config -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete pvc vector-database-data -n "$NAMESPACE" 2>/dev/null || true
    
    sleep 10
    print_info "Cleanup completed"
}

# Step 2: Validate chart and values
validate_files() {
    print_info "Step 2: Validating chart files..."
    
    local chart_path="infrastructure/helm/charts/vector-database"
    local values_file="infrastructure/helm/values/development/vector-database.yaml"
    
    if [ ! -f "$chart_path/Chart.yaml" ]; then
        print_error "Chart.yaml not found in $chart_path"
        exit 1
    fi
    
    if [ ! -f "$values_file" ]; then
        print_error "Values file not found: $values_file"
        exit 1
    fi
    
    # Check required template files
    local templates=("deployment.yaml" "service.yaml" "configmap.yaml" "pvc.yaml" "_helpers.tpl")
    for template in "${templates[@]}"; do
        if [ ! -f "$chart_path/templates/$template" ]; then
            print_error "Required template not found: $template"
            exit 1
        fi
    done
    
    print_info "File validation passed"
}

# Step 3: Create namespace and ensure prerequisites
setup_namespace() {
    print_info "Step 3: Setting up namespace..."
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        kubectl create namespace "$NAMESPACE"
        kubectl label namespace "$NAMESPACE" istio-injection=enabled
    fi
    
    print_info "Namespace ready"
}

# Step 4: Deploy with minimal configuration
deploy_minimal() {
    print_info "Step 4: Deploying with minimal configuration..."
    
    # Create a minimal values override
    cat > /tmp/vector-db-minimal.yaml << EOF
chromadb:
  image:
    registry: docker.io
    repository: chromadb/chroma
    tag: "0.4.15"
    pullPolicy: IfNotPresent
  
  resources:
    requests:
      memory: "128Mi"
      cpu: "50m"
    limits:
      memory: "512Mi"
      cpu: "200m"
  
  persistence:
    enabled: false  # Disable persistence for quick test
  
  configuration:
    host: "0.0.0.0"
    port: 8000
    cors_allow_origins: ["*"]
    log_level: "INFO"
    anonymized_telemetry: false
    chroma_db_impl: "chromadb.db.duckdb.DuckDB"
    chroma_sysdb_impl: "chromadb.sysdb.impl.sqlite.SqliteDB"
    chroma_producer_impl: "chromadb.ingest.impl.simple.SimpleProducer"
    chroma_consumer_impl: "chromadb.ingest.impl.simple.SimpleConsumer"
    chroma_segment_cache_policy: "LRU"
    chroma_segment_cache_size: 100
    max_batch_size: 1000
    chroma_server_grpc_port: 50051
  
  auth:
    enabled: false

replicaCount: 1

service:
  type: ClusterIP
  chromaPort: 8000
  chromaGrpcPort: 50051

# Security context
securityContext:
  runAsNonRoot: false
  runAsUser: 0
  fsGroup: 0

# Disable advanced features for minimal deployment
autoscaling:
  enabled: false

ingress:
  enabled: false

networkPolicy:
  enabled: false

serviceMonitor:
  enabled: false

podDisruptionBudget:
  enabled: false

backup:
  enabled: false

livenessProbe:
  enabled: true
  httpGet:
    path: "/api/v1/heartbeat"
    port: 8000
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3

readinessProbe:
  enabled: true
  httpGet:
    path: "/api/v1/heartbeat"
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

# Remove init containers for simplicity
initContainers: []
EOF
    
    # Deploy with minimal configuration
    helm upgrade --install "$RELEASE_NAME" \
        infrastructure/helm/charts/vector-database \
        -n "$NAMESPACE" \
        -f /tmp/vector-db-minimal.yaml \
        --wait --timeout 5m
    
    print_info "Minimal deployment completed"
}

# Step 5: Wait and test
test_deployment() {
    print_info "Step 5: Testing deployment..."
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vector-database -n "$NAMESPACE" --timeout=300s
    
    # Get pod name
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod_name" ]; then
        print_error "No pods found"
        return 1
    fi
    
    print_info "Testing pod: $pod_name"
    
    # Test basic connectivity
    sleep 30  # Give ChromaDB time to start
    
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/heartbeat; then
        print_status "✅ Vector Database is responding!"
    else
        print_error "Vector Database is not responding"
        print_info "Pod logs:"
        kubectl logs -n "$NAMESPACE" "$pod_name" --tail=20
        return 1
    fi
}

# Step 6: Create NodePort for external access
setup_external_access() {
    print_info "Step 6: Setting up external access..."
    
    # Create NodePort service
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: vector-database-nodeport
  namespace: $NAMESPACE
  labels:
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
    app.kubernetes.io/name: vector-database
    app.kubernetes.io/instance: $RELEASE_NAME
EOF
    
    print_info "External access configured on port 30800"
}

# Show final status
show_status() {
    print_status "Final Status:"
    echo "============="
    
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database
    
    echo
    print_info "Access Information:"
    
    if command -v minikube &>/dev/null; then
        local minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
        echo "  External: http://$minikube_ip:30800/api/v1/heartbeat"
    fi
    
    echo "  Internal: vector-database.offerkiller-data.svc.cluster.local:8000"
    echo "  Port Forward: kubectl port-forward -n offerkiller-data svc/vector-database 8000:8000"
    
    echo
    print_info "Test Commands:"
    echo "  ./scripts/test-vector-database.sh"
    echo "  kubectl logs -f deployment/vector-database -n offerkiller-data"
}

# Main execution
main() {
    # Navigate to project root
    cd "$(dirname "$0")/.."
    
    case "${1:-fix}" in
        "fix")
            cleanup_existing
            validate_files
            setup_namespace
            deploy_minimal
            test_deployment
            setup_external_access
            show_status
            print_status "✅ Vector Database quick fix completed!"
            ;;
        "test")
            test_deployment
            ;;
        "clean")
            cleanup_existing
            print_status "✅ Cleanup completed!"
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Usage: $0 [fix|test|clean|status]"
            echo "  fix:    Clean and redeploy with minimal configuration (default)"
            echo "  test:   Test existing deployment"
            echo "  clean:  Clean up existing deployment"
            echo "  status: Show current status"
            exit 1
            ;;
    esac
}

main "$@"