#!/bin/bash

# OfferKiller Vector Database Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}🚀 $1${NC}"; }
print_info() { echo -e "${CYAN}📁 $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Configuration
ENVIRONMENT="${1:-development}"
DRY_RUN="${2:-false}"
NAMESPACE="offerkiller-data"
RELEASE_NAME="vector-database"

print_status "OfferKiller Vector Database Deployment ($ENVIRONMENT)"
echo "========================================================"

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

print_info "Working directory: $(pwd)"
print_info "Target environment: $ENVIRONMENT"

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not available"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not available"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create namespace if it doesn't exist
ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_info "Creating namespace: $NAMESPACE"
        if [ "$DRY_RUN" != "true" ]; then
            kubectl create namespace "$NAMESPACE"
            kubectl label namespace "$NAMESPACE" istio-injection=enabled
        fi
    fi
}

# Validate Helm chart
validate_chart() {
    print_info "Validating Helm chart..."
    
    local chart_path="infrastructure/helm/charts/vector-database"
    local values_file="infrastructure/helm/values/$ENVIRONMENT/vector-database.yaml"
    
    if [ ! -d "$chart_path" ]; then
        print_error "Chart directory not found: $chart_path"
        exit 1
    fi
    
    if [ ! -f "$values_file" ]; then
        print_error "Values file not found: $values_file"
        exit 1
    fi
    
    # Run helm lint
    if helm lint "$chart_path" -f "$values_file"; then
        print_success "Chart validation passed"
    else
        print_error "Chart validation failed"
        exit 1
    fi
}

# Deploy vector database
deploy_vector_db() {
    print_info "Deploying Vector Database..."
    
    local chart_path="infrastructure/helm/charts/vector-database"
    local values_file="infrastructure/helm/values/$ENVIRONMENT/vector-database.yaml"
    
    local helm_cmd="helm upgrade --install $RELEASE_NAME $chart_path -n $NAMESPACE --create-namespace -f $values_file"
    
    if [ "$DRY_RUN" = "true" ]; then
        helm_cmd="$helm_cmd --dry-run"
    else
        helm_cmd="$helm_cmd --wait --timeout 10m"
    fi
    
    print_info "Command: $helm_cmd"
    
    if eval "$helm_cmd"; then
        print_success "Vector Database deployed successfully"
    else
        print_error "Failed to deploy Vector Database"
        exit 1
    fi
}

# Wait for pods to be ready
wait_for_ready() {
    if [ "$DRY_RUN" = "true" ]; then
        print_info "Skipping wait in dry run mode"
        return 0
    fi
    
    print_info "Waiting for Vector Database pods to be ready..."
    
    if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vector-database -n "$NAMESPACE" --timeout=300s; then
        print_success "Vector Database pods are ready"
    else
        print_warning "Timeout waiting for pods to be ready"
        return 1
    fi
}

# Test the deployment
test_deployment() {
    if [ "$DRY_RUN" = "true" ]; then
        print_info "Skipping tests in dry run mode"
        return 0
    fi
    
    print_info "Testing Vector Database deployment..."
    
    # Get the first pod name
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    print_info "Testing pod: $pod_name"
    
    # Test heartbeat endpoint
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/heartbeat; then
        print_success "Heartbeat test passed"
    else
        print_error "Heartbeat test failed"
        return 1
    fi
    
    # Test collections endpoint
    if kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s http://localhost:8000/api/v1/collections; then
        print_success "Collections endpoint test passed"
    else
        print_warning "Collections endpoint test failed (might be expected for new installation)"
    fi
}

# Show deployment status
show_status() {
    if [ "$DRY_RUN" = "true" ]; then
        return 0
    fi
    
    echo
    print_info "Deployment Status:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database
    kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database
    kubectl get pvc -n "$NAMESPACE"
    
    echo
    print_info "Helm Release Status:"
    helm status "$RELEASE_NAME" -n "$NAMESPACE"
}

# Show access information
show_access_info() {
    if [ "$DRY_RUN" = "true" ]; then
        return 0
    fi
    
    echo
    print_info "Access Information:"
    
    # Try to get minikube IP
    local cluster_ip="localhost"
    if command -v minikube &> /dev/null; then
        cluster_ip=$(minikube ip 2>/dev/null || echo "localhost")
    fi
    
    echo "   Internal Service: vector-database.offerkiller-data.svc.cluster.local:8000"
    echo "   External Access:  http://$cluster_ip:30800"
    echo "   Port Forward:     kubectl port-forward -n offerkiller-data svc/vector-database 8000:8000"
    
    echo
    print_info "Test Commands:"
    echo "   curl http://$cluster_ip:30800/api/v1/heartbeat"
    echo "   curl http://$cluster_ip:30800/api/v1/collections"
    
    echo
    print_info "Useful Commands:"
    echo "   kubectl logs -f deployment/vector-database -n offerkiller-data"
    echo "   kubectl exec -it deployment/vector-database -n offerkiller-data -- /bin/bash"
    echo "   kubectl describe pod -l app.kubernetes.io/name=vector-database -n offerkiller-data"
}

# Cleanup function
cleanup() {
    print_info "Cleaning up Vector Database deployment..."
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
    kubectl delete pvc -l app.kubernetes.io/name=vector-database -n "$NAMESPACE" || true
    print_success "Cleanup completed"
}

# Main function
main() {
    case "${3:-deploy}" in
        "deploy")
            check_prerequisites
            ensure_namespace
            validate_chart
            deploy_vector_db
            wait_for_ready
            test_deployment
            show_status
            show_access_info
            print_success "Vector Database deployment completed!"
            ;;
        "test")
            test_deployment
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Usage: $0 [environment] [dry_run] [action]"
            echo "  environment: development|staging|production (default: development)"
            echo "  dry_run: true|false (default: false)"
            echo "  action: deploy|test|status|cleanup (default: deploy)"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"