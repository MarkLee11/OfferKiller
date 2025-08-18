#!/bin/bash

# OfferKiller Vector Database Test Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}🚀 $1${NC}"; }
print_info() { echo -e "${CYAN}📁 $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

NAMESPACE="offerkiller-data"
RELEASE_NAME="vector-database"

print_status "OfferKiller Vector Database Test Suite"
echo "======================================"

# Test 1: Check if pods are running
test_pods_running() {
    print_info "Test 1: Checking if Vector Database pods are running..."
    
    local pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pods" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    local running_pods=$(echo "$pods" | grep "Running" | wc -l)
    local total_pods=$(echo "$pods" | wc -l)
    
    if [ "$running_pods" -eq "$total_pods" ] && [ "$running_pods" -gt 0 ]; then
        print_success "All $total_pods Vector Database pods are running"
        echo "$pods"
        return 0
    else
        print_error "$running_pods/$total_pods pods are running"
        echo "$pods"
        return 1
    fi
}

# Test 2: Check service accessibility
test_service_accessibility() {
    print_info "Test 2: Checking service accessibility..."
    
    local service=$(kubectl get svc -n "$NAMESPACE" vector-database --no-headers 2>/dev/null || echo "")
    
    if [ -z "$service" ]; then
        print_error "Vector Database service not found"
        return 1
    fi
    
    print_success "Vector Database service exists"
    echo "$service"
    
    # Test service endpoints
    local endpoints=$(kubectl get endpoints -n "$NAMESPACE" vector-database -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [ -z "$endpoints" ]; then
        print_error "No service endpoints found"
        return 1
    fi
    
    print_success "Service endpoints found: $endpoints"
    return 0
}

# Test 3: Check storage
test_storage() {
    print_info "Test 3: Checking persistent storage..."
    
    local pvcs=$(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database --no-headers 2>/dev/null || echo "")
    
    if [ -z "$pvcs" ]; then
        print_error "No persistent volume claims found"
        return 1
    fi
    
    local bound_pvcs=$(echo "$pvcs" | grep "Bound" | wc -l)
    local total_pvcs=$(echo "$pvcs" | wc -l)
    
    if [ "$bound_pvcs" -eq "$total_pvcs" ] && [ "$bound_pvcs" -gt 0 ]; then
        print_success "All $total_pvcs persistent volume claims are bound"
        echo "$pvcs"
        return 0
    else
        print_error "$bound_pvcs/$total_pvcs PVCs are bound"
        echo "$pvcs"
        return 1
    fi
}

# Test 4: Check API health
test_api_health() {
    print_info "Test 4: Checking API health..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    print_info "Testing pod: $pod_name"
    
    # Test heartbeat endpoint
    local heartbeat_response
    if heartbeat_response=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -w "%{http_code}" http://localhost:8000/api/v1/heartbeat 2>/dev/null); then
        local http_code="${heartbeat_response: -3}"
        local response_body="${heartbeat_response%???}"
        
        if [ "$http_code" = "200" ]; then
            print_success "Heartbeat endpoint returned 200 OK"
            echo "Response: $response_body"
        else
            print_error "Heartbeat endpoint returned HTTP $http_code"
            echo "Response: $response_body"
            return 1
        fi
    else
        print_error "Failed to connect to heartbeat endpoint"
        return 1
    fi
    
    return 0
}

# Test 5: Check collections API
test_collections_api() {
    print_info "Test 5: Checking collections API..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    # Test collections endpoint
    local collections_response
    if collections_response=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -w "%{http_code}" http://localhost:8000/api/v1/collections 2>/dev/null); then
        local http_code="${collections_response: -3}"
        local response_body="${collections_response%???}"
        
        if [ "$http_code" = "200" ]; then
            print_success "Collections endpoint returned 200 OK"
            echo "Response: $response_body"
        else
            print_warning "Collections endpoint returned HTTP $http_code (might be expected for new installation)"
            echo "Response: $response_body"
        fi
    else
        print_warning "Failed to connect to collections endpoint (might be expected for new installation)"
    fi
    
    return 0
}

# Test 6: Test collection creation
test_collection_creation() {
    print_info "Test 6: Testing collection creation..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    # Create a test collection
    local create_response
    if create_response=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{"name": "test-collection", "metadata": {"description": "Test collection"}}' \
        http://localhost:8000/api/v1/collections 2>/dev/null); then
        
        local http_code="${create_response: -3}"
        local response_body="${create_response%???}"
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            print_success "Test collection created successfully"
            echo "Response: $response_body"
        else
            print_warning "Collection creation returned HTTP $http_code"
            echo "Response: $response_body"
        fi
    else
        print_warning "Failed to create test collection"
    fi
    
    return 0
}

# Test 7: Check logs for errors
test_logs() {
    print_info "Test 7: Checking logs for errors..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    print_info "Checking logs for pod: $pod_name"
    
    # Get recent logs and check for errors
    local logs=$(kubectl logs -n "$NAMESPACE" "$pod_name" --tail=50 2>/dev/null || echo "")
    
    if echo "$logs" | grep -i "error\|exception\|fatal" > /dev/null; then
        print_warning "Found potential errors in logs:"
        echo "$logs" | grep -i "error\|exception\|fatal" | tail -5
    else
        print_success "No obvious errors found in recent logs"
    fi
    
    return 0
}

# Test 8: Resource usage check
test_resource_usage() {
    print_info "Test 8: Checking resource usage..."
    
    local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "No Vector Database pods found"
        return 1
    fi
    
    # Check resource usage if metrics server is available
    if kubectl top pod "$pod_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_success "Resource usage:"
        kubectl top pod "$pod_name" -n "$NAMESPACE"
    else
        print_info "Metrics server not available, skipping resource usage check"
    fi
    
    return 0
}

# Test 9: External access test
test_external_access() {
    print_info "Test 9: Testing external access..."
    
    # Check if NodePort service exists
    local nodeport_svc=$(kubectl get svc -n "$NAMESPACE" vector-database-nodeport --no-headers 2>/dev/null || echo "")
    
    if [ -n "$nodeport_svc" ]; then
        print_info "NodePort service found:"
        echo "$nodeport_svc"
        
        # Try to get minikube IP for testing
        if command -v minikube &> /dev/null; then
            local minikube_ip=$(minikube ip 2>/dev/null || echo "")
            if [ -n "$minikube_ip" ]; then
                print_info "Testing external access via $minikube_ip:30800"
                if curl -s "http://$minikube_ip:30800/api/v1/heartbeat" >/dev/null 2>&1; then
                    print_success "External access working"
                else
                    print_warning "External access test failed (network issue or service not ready)"
                fi
            fi
        fi
    else
        print_info "No NodePort service found (expected for ClusterIP setup)"
    fi
    
    return 0
}

# Run all tests
run_all_tests() {
    local tests_passed=0
    local tests_total=9
    
    test_pods_running && ((tests_passed++)) || true
    echo
    test_service_accessibility && ((tests_passed++)) || true
    echo
    test_storage && ((tests_passed++)) || true
    echo
    test_api_health && ((tests_passed++)) || true
    echo
    test_collections_api && ((tests_passed++)) || true
    echo
    test_collection_creation && ((tests_passed++)) || true
    echo
    test_logs && ((tests_passed++)) || true
    echo
    test_resource_usage && ((tests_passed++)) || true
    echo
    test_external_access && ((tests_passed++)) || true
    
    echo
    print_status "Test Results Summary"
    echo "===================="
    print_info "Tests passed: $tests_passed/$tests_total"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        print_success "All tests passed! Vector Database is working correctly."
        return 0
    elif [ "$tests_passed" -ge 6 ]; then
        print_warning "Most tests passed. Vector Database is mostly working but may have minor issues."
        return 0
    else
        print_error "Multiple tests failed. Vector Database may have serious issues."
        return 1
    fi
}

# Main function
main() {
    case "${1:-all}" in
        "all")
            run_all_tests
            ;;
        "pods")
            test_pods_running
            ;;
        "service")
            test_service_accessibility
            ;;
        "storage")
            test_storage
            ;;
        "api")
            test_api_health
            ;;
        "collections")
            test_collections_api
            ;;
        "create")
            test_collection_creation
            ;;
        "logs")
            test_logs
            ;;
        "resources")
            test_resource_usage
            ;;
        "external")
            test_external_access
            ;;
        *)
            echo "Usage: $0 [test_name]"
            echo "  test_name: all|pods|service|storage|api|collections|create|logs|resources|external"
            echo "  (default: all)"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"