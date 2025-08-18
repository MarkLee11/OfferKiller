#!/bin/bash

# OfferKiller Data Layer Deployment Script for Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="development"
DRY_RUN=false
SKIP_REDIS=false
SKIP_RABBITMQ=false
SKIP_VECTOR_DB=false
KUBECONFIG_PATH=""
TIMEOUT=300
FORCE=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_info() {
    echo -e "${CYAN}$1${NC}"
}

# Function to show help
show_help() {
    cat << EOF
OfferKiller Data Layer Deployment Script

Usage: $0 [OPTIONS]

Options:
    -e, --environment ENV   Target environment (development/staging/production) [default: development]
    -d, --dry-run          Perform a dry run without actually deploying
    -k, --kubeconfig PATH  Path to kubeconfig file
    -r, --skip-redis       Skip Redis cluster deployment
    -q, --skip-rabbitmq    Skip RabbitMQ cluster deployment
    -v, --skip-vector-db   Skip Vector Database deployment
    -f, --force            Force deployment even if already exists
    -t, --timeout SECONDS  Timeout for waiting operations [default: 300]
    -h, --help             Show this help message

Examples:
    $0                                        # Deploy everything to development
    $0 --environment staging                  # Deploy to staging environment
    $0 --dry-run                             # Dry run mode
    $0 --skip-redis --skip-rabbitmq          # Deploy only vector database
    $0 --kubeconfig ~/.kube/config           # Use specific kubeconfig

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -k|--kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        -r|--skip-redis)
            SKIP_REDIS=true
            shift
            ;;
        -q|--skip-rabbitmq)
            SKIP_RABBITMQ=true
            shift
            ;;
        -v|--skip-vector-db)
            SKIP_VECTOR_DB=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# Set kubeconfig if provided
if [[ -n "$KUBECONFIG_PATH" ]]; then
    export KUBECONFIG="$KUBECONFIG_PATH"
    print_warning "Using kubeconfig: $KUBECONFIG_PATH"
fi

print_status "🚀 OfferKiller Data Layer Deployment ($ENVIRONMENT)"
print_status "======================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_info "🔍 Checking prerequisites..."
    
    if ! command_exists kubectl; then
        print_error "❌ kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "❌ Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    # Test cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_status "✅ Prerequisites check passed"
    
    # Create required namespaces
    for namespace in "offerkiller-data" "offerkiller-system"; do
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            print_warning "📦 Creating namespace: $namespace"
            if [[ "$DRY_RUN" != "true" ]]; then
                kubectl create namespace "$namespace"
                kubectl label namespace "$namespace" istio-injection=enabled
            fi
        fi
    done
}

# Function to deploy Helm chart
deploy_helm_chart() {
    local chart_path="$1"
    local release_name="$2"
    local namespace="$3"
    local values_file="$4"
    local description="$5"
    
    print_info "📦 Deploying $description..."
    
    local helm_cmd="helm upgrade --install $release_name $chart_path -n $namespace --create-namespace"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd="$helm_cmd -f $values_file"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
    else
        helm_cmd="$helm_cmd --wait --timeout 10m"
    fi
    
    if [[ "$FORCE" == "true" ]]; then
        helm_cmd="$helm_cmd --force"
    fi
    
    print_info "🔧 Command: $helm_cmd"
    
    if eval "$helm_cmd"; then
        print_status "✅ $description deployed successfully"
        return 0
    else
        print_error "❌ Failed to deploy $description"
        return 1
    fi
}

# Function to wait for deployment
wait_for_deployment() {
    local namespace="$1"
    local deployment_name="$2"
    local timeout_seconds="${3:-$TIMEOUT}"
    
    print_warning "⏳ Waiting for $deployment_name in $namespace to be ready..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "🏃 Skipping wait in dry run mode"
        return 0
    fi
    
    local end_time=$((SECONDS + timeout_seconds))
    
    while [[ $SECONDS -lt $end_time ]]; do
        local ready=$(kubectl get statefulset "$deployment_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$(kubectl get statefulset "$deployment_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            print_status "✅ $deployment_name is ready!"
            return 0
        fi
        
        # Also check for deployments (for vector database)
        local ready_deploy=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_deploy=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready_deploy" == "$desired_deploy" && "$ready_deploy" -gt 0 ]]; then
            print_status "✅ $deployment_name is ready!"
            return 0
        fi
        
        sleep 10
    done
    
    print_warning "⚠️ Timeout waiting for $deployment_name to be ready"
    return 1
}

# Function to verify services
verify_services() {
    print_info "🔍 Verifying services..."
    
    if [[ "$SKIP_REDIS" != "true" ]]; then
        print_warning "Testing Redis cluster..."
        if kubectl exec -n offerkiller-data redis-cluster-0 -- redis-cli ping >/dev/null 2>&1; then
            print_status "✅ Redis cluster is responding"
        else
            print_warning "⚠️ Redis cluster is not responding"
        fi
    fi
    
    if [[ "$SKIP_RABBITMQ" != "true" ]]; then
        print_warning "Testing RabbitMQ cluster..."
        if kubectl exec -n offerkiller-data rabbitmq-ha-0 -- rabbitmqctl status --quiet >/dev/null 2>&1; then
            print_status "✅ RabbitMQ cluster is operational"
        else
            print_warning "⚠️ RabbitMQ cluster has issues"
        fi
    fi
    
    if [[ "$SKIP_VECTOR_DB" != "true" ]]; then
        print_warning "Testing Vector Database..."
        # Find the actual pod name since vector-database uses deployment
        local vector_pod=$(kubectl get pods -n offerkiller-data -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$vector_pod" ]] && kubectl exec -n offerkiller-data "$vector_pod" -- curl -s http://localhost:8000/api/v1/heartbeat >/dev/null 2>&1; then
            print_status "✅ Vector Database is responding"
        else
            print_warning "⚠️ Vector Database is not responding"
        fi
    fi
}

# Main deployment function
main() {
    check_prerequisites
    
    # Navigate to project root
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(dirname "$script_dir")"
    cd "$project_root"
    
    print_warning "📂 Working directory: $(pwd)"
    print_warning "🎯 Target environment: $ENVIRONMENT"
    
    # Add required Helm repositories
    print_info "📦 Adding Helm repositories..."
    helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    
    # Deploy Redis Cluster
    if [[ "$SKIP_REDIS" != "true" ]]; then
        local values_file="infrastructure/helm/values/$ENVIRONMENT/redis-cluster.yaml"
        if deploy_helm_chart "infrastructure/helm/charts/redis-cluster" \
                           "redis-cluster" \
                           "offerkiller-data" \
                           "$values_file" \
                           "Redis Cluster"; then
            wait_for_deployment "offerkiller-data" "redis-cluster"
        else
            print_error "❌ Redis deployment failed"
            exit 1
        fi
    fi
    
    # Deploy RabbitMQ Cluster
    if [[ "$SKIP_RABBITMQ" != "true" ]]; then
        local values_file="infrastructure/helm/values/$ENVIRONMENT/rabbitmq-ha.yaml"
        if deploy_helm_chart "infrastructure/helm/charts/rabbitmq-ha" \
                           "rabbitmq-ha" \
                           "offerkiller-data" \
                           "$values_file" \
                           "RabbitMQ HA Cluster"; then
            wait_for_deployment "offerkiller-data" "rabbitmq-ha"
        else
            print_error "❌ RabbitMQ deployment failed"
            exit 1
        fi
    fi
    
    # Deploy Vector Database
    if [[ "$SKIP_VECTOR_DB" != "true" ]]; then
        local values_file="infrastructure/helm/values/$ENVIRONMENT/vector-database.yaml"
        if deploy_helm_chart "infrastructure/helm/charts/vector-database" \
                           "vector-database" \
                           "offerkiller-data" \
                           "$values_file" \
                           "Vector Database"; then
            wait_for_deployment "offerkiller-data" "vector-database"
        else
            print_error "❌ Vector Database deployment failed"
            exit 1
        fi
    fi
    
    # Verify deployments
    if [[ "$DRY_RUN" != "true" ]]; then
        echo
        print_warning "🔍 Deployment Status:"
        kubectl get pods -n offerkiller-data
        kubectl get svc -n offerkiller-data
        kubectl get pvc -n offerkiller-data
        
        # Verify services
        verify_services
        
        echo
        print_status "🎉 Data layer deployment completed!"
        
        # Get minikube IP for access information
        local minikube_ip=""
        if command_exists minikube; then
            minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
        else
            minikube_ip="localhost"
        fi
        
        echo
        print_warning "📝 Access Information:"
        print_info "   Redis Cluster:     $minikube_ip:30379"
        print_info "   RabbitMQ Mgmt:     http://$minikube_ip:31672 (offerkilleruser/rabbitmq123change)"
        print_info "   Vector Database:   http://$minikube_ip:30800"
        
        echo
        print_warning "🔧 Useful Commands:"
        echo "   kubectl get pods -n offerkiller-data"
        echo "   kubectl logs -f statefulset/redis-cluster -n offerkiller-data"
        echo "   kubectl logs -f statefulset/rabbitmq-ha -n offerkiller-data"
        echo "   kubectl logs -f deployment/vector-database -n offerkiller-data"
        
        echo
        print_status "🚀 Ready for application deployment!"
    else
        print_status "✅ Dry run completed successfully"
    fi
}

# Run main function
main "$@"
