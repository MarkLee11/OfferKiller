#!/bin/bash

# OfferKiller Data Layer Backup Script

set -e

BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/tmp/offerkiller-backups/$BACKUP_DATE"
NAMESPACE="offerkiller-data"

echo "📦 OfferKiller Data Layer Backup - $BACKUP_DATE"
echo "==============================================="

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup Redis
backup_redis() {
    echo "🔴 Backing up Redis cluster..."
    
    # Create Redis dump
    kubectl exec -n $NAMESPACE redis-cluster-0 -- redis-cli BGSAVE
    
    # Wait for backup to complete
    while [ "$(kubectl exec -n $NAMESPACE redis-cluster-0 -- redis-cli LASTSAVE)" = "$(kubectl exec -n $NAMESPACE redis-cluster-0 -- redis-cli LASTSAVE)" ]; do
        sleep 1
    done
    
    # Copy dump file
    kubectl cp $NAMESPACE/redis-cluster-0:/data/dump.rdb "$BACKUP_DIR/redis-dump.rdb"
    
    # Export cluster configuration
    kubectl get configmap redis-cluster-config -n $NAMESPACE -o yaml > "$BACKUP_DIR/redis-config.yaml"
    
    echo "✅ Redis backup completed"
}

# Function to backup RabbitMQ
backup_rabbitmq() {
    echo "🐰 Backing up RabbitMQ cluster..."
    
    # Export definitions
    kubectl exec -n $NAMESPACE rabbitmq-ha-0 -- rabbitmqctl export_definitions /tmp/rabbitmq-definitions.json
    kubectl cp $NAMESPACE/rabbitmq-ha-0:/tmp/rabbitmq-definitions.json "$BACKUP_DIR/rabbitmq-definitions.json"
    
    # Backup persistent data
    kubectl exec -n $NAMESPACE rabbitmq-ha-0 -- tar -czf /tmp/rabbitmq-data.tar.gz /var/lib/rabbitmq/
    kubectl cp $NAMESPACE/rabbitmq-ha-0:/tmp/rabbitmq-data.tar.gz "$BACKUP_DIR/rabbitmq-data.tar.gz"
    
    # Export configuration
    kubectl get configmap rabbitmq-ha-config -n $NAMESPACE -o yaml > "$BACKUP_DIR/rabbitmq-config.yaml"
    
    echo "✅ RabbitMQ backup completed"
}

# Function to backup Vector Database
backup_vector_database() {
    echo "🧠 Backing up Vector Database..."
    
    # Find the actual pod name
    vector_pod=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=vector-database -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$vector_pod" ]; then
        # Backup ChromaDB data
        kubectl exec -n $NAMESPACE "$vector_pod" -- tar -czf /tmp/chromadb-data.tar.gz /chroma/chroma/
        kubectl cp $NAMESPACE/"$vector_pod":/tmp/chromadb-data.tar.gz "$BACKUP_DIR/chromadb-data.tar.gz"
        
        # Export collections metadata
        kubectl port-forward -n $NAMESPACE svc/vector-database 8000:8000 &
        port_forward_pid=$!
        
        sleep 5
        
        # Export collections list
        curl -s http://localhost:8000/api/v1/collections > "$BACKUP_DIR/chromadb-collections.json" || true
        
        kill $port_forward_pid 2>/dev/null || true
        
        # Export configuration
        kubectl get configmap vector-database-config -n $NAMESPACE -o yaml > "$BACKUP_DIR/vector-database-config.yaml"
        
        echo "✅ Vector Database backup completed"
    else
        echo "⚠️ Vector Database pod not found"
    fi
}

# Function to backup Kubernetes resources
backup_kubernetes_resources() {
    echo "☸️ Backing up Kubernetes resources..."
    
    # Backup all resources in the namespace
    kubectl get all -n $NAMESPACE -o yaml > "$BACKUP_DIR/kubernetes-resources.yaml"
    kubectl get pvc -n $NAMESPACE -o yaml > "$BACKUP_DIR/persistent-volume-claims.yaml"
    kubectl get secrets -n $NAMESPACE -o yaml > "$BACKUP_DIR/secrets.yaml"
    kubectl get configmaps -n $NAMESPACE -o yaml > "$BACKUP_DIR/configmaps.yaml"
    
    echo "✅ Kubernetes resources backup completed"
}

# Execute backups
backup_redis
backup_rabbitmq
backup_vector_database
backup_kubernetes_resources

# Create backup metadata
cat > "$BACKUP_DIR/backup-metadata.json" << EOF
{
  "backup_date": "$BACKUP_DATE",
  "namespace": "$NAMESPACE",
  "services": ["redis-cluster", "rabbitmq-ha", "vector-database"],
  "backup_size": "$(du -sh $BACKUP_DIR | cut -f1)",
  "kubernetes_version": "$(kubectl version --short --client)",
  "cluster_info": "$(kubectl cluster-info | head -1)"
}
EOF

# Compress backup
tar -czf "/tmp/offerkiller-backup-$BACKUP_DATE.tar.gz" -C "/tmp/offerkiller-backups" "$BACKUP_DATE"

echo "📦 Backup completed: /tmp/offerkiller-backup-$BACKUP_DATE.tar.gz"
echo "📊 Backup size: $(du -sh /tmp/offerkiller-backup-$BACKUP_DATE.tar.gz | cut -f1)"

# Cleanup temporary directory
rm -rf "$BACKUP_DIR"

echo "✅ Backup process completed successfully!"
