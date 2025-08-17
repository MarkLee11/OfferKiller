# Infrastructure

Infrastructure as Code for OfferKiller deployment and operations.

## Components

### Kubernetes
- Base manifests for all services
- Environment-specific configurations
- Service meshes and ingress

### Helm Charts
- Parameterized deployments
- Environment-specific values
- Dependency management

### Terraform
- Cloud infrastructure provisioning
- Multi-environment support
- State management

### Monitoring
- Prometheus configuration
- Grafana dashboards
- Jaeger tracing setup
- ELK stack configuration

## Directory Structure

```
infrastructure/
├── kubernetes/
│   ├── base/                   # Base Kubernetes manifests
│   ├── environments/           # Environment overlays
│   └── services/              # Service-specific configs
├── helm/
│   ├── charts/                # Helm charts
│   └── values/                # Environment values
├── terraform/
│   ├── modules/               # Reusable modules
│   └── environments/          # Environment configs
└── monitoring/
    ├── prometheus/            # Metrics collection
    ├── grafana/              # Dashboards
    ├── jaeger/               # Distributed tracing
    └── elasticsearch/         # Log aggregation
```

## Deployment

### Local Development
```bash
docker-compose up -d
```

### Kubernetes
```bash
# Apply base configuration
kubectl apply -k infrastructure/kubernetes/base/

# Apply environment-specific config
kubectl apply -k infrastructure/kubernetes/environments/dev/
```

### Helm
```bash
# Install/upgrade release
helm upgrade --install offerkiller \
  infrastructure/helm/charts/offerkiller/ \
  --values infrastructure/helm/values/dev.yaml
```

### Terraform
```bash
cd infrastructure/terraform/environments/dev/
terraform init
terraform plan
terraform apply
```

## Monitoring Setup

Access monitoring tools:
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Jaeger: `http://localhost:16686`
- Kibana: `http://localhost:5601`
