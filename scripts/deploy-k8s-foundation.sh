#!/bin/bash

# OfferKiller Kubernetes Foundation Deployment Script for Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
SKIP_ISTIO=false
SKIP_MONITORING=false
KUBECONFIG_PATH=""
TIMEOUT=300

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
OfferKiller Kubernetes Foundation Deployment Script

Usage: $0 [OPTIONS]

Options:
    -d, --dry-run          Perform a dry run without actually deploying
    -k, --kubeconfig PATH  Path to kubeconfig file
    -s, --skip-istio       Skip Istio service mesh deployment
    -m, --skip-monitoring  Skip monitoring stack deployment
    -t, --timeout SECONDS  Timeout for waiting operations (default: 300)
    -h, --help             Show this help message

Examples:
    $0                                    # Deploy everything
    $0 --dry-run                         # Dry run mode
    $0 --skip-istio --skip-monitoring    # Deploy only core services
    $0 --kubeconfig ~/.kube/config       # Use specific kubeconfig

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -k|--kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        -s|--skip-istio)
            SKIP_ISTIO=true
            shift
            ;;
        -m|--skip-monitoring)
            SKIP_MONITORING=true
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

print_status "🚀 OfferKiller Kubernetes Foundation Deployment"
print_status "================================================="

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
}

# Function to apply Kubernetes manifests
deploy_manifests() {
    local path="$1"
    local description="$2"
    
    print_info "📦 Deploying $description..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f "$path" --dry-run=client
    else
        kubectl apply -f "$path"
    fi
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ $description deployed successfully"
    else
        print_error "❌ Failed to deploy $description"
        exit 1
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
        local ready=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [[ "$ready" == "$desired" && "$ready" -gt 0 ]]; then
            print_status "✅ $deployment_name is ready!"
            return 0
        fi
        
        sleep 10
    done
    
    print_warning "⚠️ Timeout waiting for $deployment_name to be ready"
    return 1
}

# Function to deploy Helm chart
deploy_helm_chart() {
    local release_name="$1"
    local chart="$2"
    local namespace="$3"
    local values_file="$4"
    local description="$5"
    
    print_info "📦 Deploying $description via Helm..."
    
    local helm_cmd="helm install $release_name $chart -n $namespace --create-namespace"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd="$helm_cmd -f $values_file"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
    else
        helm_cmd="$helm_cmd --wait --timeout 10m"
    fi
    
    eval "$helm_cmd"
    
    if [[ $? -eq 0 ]]; then
        print_status "✅ $description deployed successfully"
    else
        print_error "❌ Failed to deploy $description"
        exit 1
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
    
    # 1. Deploy Namespaces
    deploy_manifests "infrastructure/kubernetes/foundational/namespace.yaml" "Namespaces"
    
    # 2. Deploy Security Configuration
    deploy_manifests "infrastructure/kubernetes/foundational/security/" "Security Policies"
    
    # 3. Deploy MySQL for Nacos
    deploy_manifests "infrastructure/kubernetes/foundational/nacos/mysql-nacos.yaml" "MySQL for Nacos"
    wait_for_deployment "offerkiller-system" "mysql-nacos"
    
    # 4. Deploy Nacos
    deploy_manifests "infrastructure/kubernetes/foundational/nacos/" "Nacos Service Registry"
    wait_for_deployment "offerkiller-system" "nacos"
    
    # 5. Deploy Istio (if not skipped)
    if [[ "$SKIP_ISTIO" != "true" ]]; then
        print_info "🕸️ Deploying Istio Service Mesh..."
        
        # Add Istio Helm repository
        helm repo add istio https://istio-release.storage.googleapis.com/charts
        helm repo update
        
        # Install Istio components
        deploy_helm_chart "istio-base" "istio/base" "istio-system" "" "Istio Base"
        deploy_helm_chart "istiod" "istio/istiod" "istio-system" "" "Istio Control Plane"
        
        # Skip Istio Ingress Gateway for now due to Helm chart compatibility issues
        print_warning "⚠️ Skipping Istio Ingress Gateway due to Helm chart compatibility issues"
        print_info "💡 Core services (Nacos) will work fine without ingress gateway"
        
        # Wait for Istio to be ready
        if [[ "$DRY_RUN" != "true" ]]; then
            sleep 30
        fi
        
        # Deploy Istio configurations
        deploy_manifests "infrastructure/kubernetes/foundational/istio/" "Istio Configuration"
        
        print_status "✅ Istio Service Mesh deployed"
    fi
    
    # 6. Deploy Monitoring Stack (if not skipped)
    if [[ "$SKIP_MONITORING" != "true" ]]; then
        print_info "📊 Deploying Monitoring Stack..."
        
        # Add Helm repositories
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
        helm repo update
        
        # Install Prometheus Operator
        deploy_helm_chart "prometheus-stack" "prometheus-community/kube-prometheus-stack" \
            "offerkiller-monitoring" \
            "infrastructure/kubernetes/foundational/monitoring/prometheus/values.yaml" \
            "Prometheus Stack"
        
        # Install Jaeger
        deploy_helm_chart "jaeger" "jaegertracing/jaeger" "offerkiller-monitoring" "" "Jaeger Tracing"
        
        print_status "✅ Monitoring Stack deployed"
    fi
    
    # 7. Verify Deployment
    print_info "🔍 Verifying deployment..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo
        print_warning "📋 Deployment Status:"
        kubectl get pods -n offerkiller-system
        kubectl get pods -n istio-system 2>/dev/null || true
        kubectl get pods -n offerkiller-monitoring 2>/dev/null || true
        
        echo
        print_warning "🌐 Service Status:"
        kubectl get svc -n offerkiller-system
        kubectl get svc -n istio-system 2>/dev/null || true
        
        echo
        print_status "🎉 Foundation deployment completed!"
        
        # Get minikube IP for access information
        local minikube_ip=""
        if command_exists minikube; then
            minikube_ip=$(minikube ip 2>/dev/null || echo "localhost")
        else
            minikube_ip="localhost"
        fi
        
        echo
        print_warning "📝 Access Information:"
        print_info "   Nacos Console:     http://$minikube_ip:30848/nacos (nacos/nacos)"
        print_info "   Grafana:           http://$minikube_ip:30300 (admin/admin123)"
        print_info "   Prometheus:        http://$minikube_ip:30900"
        print_info "   Jaeger:            http://$minikube_ip:30686"
        
        echo
        print_warning "🔧 Next Steps:"
        echo "   1. Verify all services are running"
        echo "   2. Configure applications to use Nacos for service discovery"
        echo "   3. Deploy application services"
        echo "   4. Configure monitoring dashboards"
    else
        print_status "✅ Dry run completed successfully"
    fi
}

# Run main function
main "$@"
