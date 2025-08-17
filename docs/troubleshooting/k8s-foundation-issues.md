# Kubernetes Foundation Troubleshooting Guide

## Common Issues and Solutions

### 1. Minikube Startup Issues

**Problem**: Minikube fails to start with insufficient resources
```bash
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=50gb
```

**Solution**: Increase VM resources or use different driver
```bash
# Stop and delete existing cluster
minikube stop
minikube delete

# Start with more resources
minikube start --driver=docker --cpus=6 --memory=12288 --disk-size=80gb

# Or try different driver
minikube start --driver=virtualbox --cpus=4 --memory=8192
```

### 2. Nacos Connection Issues

**Problem**: Nacos fails to connect to MySQL
```bash
kubectl logs deployment/nacos -n offerkiller-system
```

**Solution**: Check MySQL service and credentials
```bash
# Check MySQL pod status
kubectl get pods -n offerkiller-system | grep mysql

# Check MySQL logs
kubectl logs deployment/mysql-nacos -n offerkiller-system

# Test MySQL connection
kubectl exec -it deployment/mysql-nacos -n offerkiller-system -- mysql -u nacos -p
```

### 3. Istio Installation Issues

**Problem**: Istio components fail to start
```bash
kubectl get pods -n istio-system
```

**Solution**: Reinstall Istio components
```bash
# Remove existing installation
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

# Reinstall
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingressgateway istio/gateway -n istio-system --wait
```

### 4. Service Discovery Issues

**Problem**: Services cannot find each other through Nacos
```bash
# Check Nacos service registry
curl -X GET "http://$(minikube ip):30848/nacos/v1/ns/catalog/services"
```

**Solution**: Verify service registration configuration
```bash
# Check application configuration
kubectl get configmap spring-boot-common-config -n offerkiller-app -o yaml

# Check service logs for registration errors
kubectl logs deployment/user-service -n offerkiller-app
```

### 5. Memory and Resource Issues

**Problem**: Pods are OOMKilled or pending due to insufficient resources
```bash
kubectl top nodes
kubectl top pods -A
```

**Solution**: Adjust resource requests and limits
```bash
# Scale down non-essential services
kubectl scale deployment prometheus-stack-kube-state-metrics -n offerkiller-monitoring --replicas=0

# Increase VM resources or use resource-optimized configurations
```

### 6. Network Policy Issues

**Problem**: Services cannot communicate due to network policies
```bash
kubectl get networkpolicy -A
```

**Solution**: Review and adjust network policies
```bash
# Temporarily disable network policies for testing
kubectl delete networkpolicy --all -n offerkiller-system
kubectl delete networkpolicy --all -n offerkiller-app

# Re-apply with corrected configurations
kubectl apply -f infrastructure/kubernetes/foundational/security/network-policies.yaml
```

## Diagnostic Commands

### General Cluster Health
```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide

# Resource usage
kubectl top nodes
kubectl top pods -A

# Events
kubectl get events --sort-by=.metadata.creationTimestamp -A
```

### Service-Specific Diagnostics
```bash
# Nacos
kubectl describe pod -l app=nacos -n offerkiller-system
kubectl logs -l app=nacos -n offerkiller-system --tail=100

# MySQL
kubectl describe pod -l app=mysql-nacos -n offerkiller-system
kubectl logs -l app=mysql-nacos -n offerkiller-system --tail=100

# Istio
kubectl describe pod -l app=istiod -n istio-system
kubectl logs -l app=istiod -n istio-system --tail=100
```

### Network Troubleshooting
```bash
# Check service endpoints
kubectl get endpoints -A

# Test service connectivity
kubectl run test-pod --image=nicolaka/netshoot --rm -it -- /bin/bash
# Inside the pod:
nslookup nacos.offerkiller-system.svc.cluster.local
curl http://nacos.offerkiller-system.svc.cluster.local:8848/nacos/v1/console/health
```

## Performance Optimization

### Resource Optimization
```bash
# Reduce resource requests for development
kubectl patch deployment nacos -n offerkiller-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"nacos","resources":{"requests":{"memory":"512Mi","cpu":"250m"}}}]}}}}'

# Use horizontal pod autoscaling
kubectl autoscale deployment nacos -n offerkiller-system --cpu-percent=70 --min=1 --max=3
```

### Storage Optimization
```bash
# Check storage usage
kubectl get pvc -A
kubectl describe pvc -A

# Clean up old data if needed
kubectl exec -it deployment/mysql-nacos -n offerkiller-system -- mysql -u root -p -e "SHOW DATABASES;"
```

## Recovery Procedures

### Complete Reset
```bash
# Stop and clean everything
./scripts/deploy-k8s-foundation.sh --help
kubectl delete namespace offerkiller-system offerkiller-app offerkiller-monitoring istio-system --force --grace-period=0

# Wait for cleanup
kubectl get namespaces

# Redeploy
./scripts/deploy-k8s-foundation.sh
```

### Partial Reset (Nacos only)
```bash
# Reset Nacos and MySQL
kubectl delete deployment nacos mysql-nacos -n offerkiller-system
kubectl delete pvc nacos-data-pvc nacos-logs-pvc mysql-nacos-pvc -n offerkiller-system

# Redeploy Nacos components
kubectl apply -f infrastructure/kubernetes/foundational/nacos/
```
