# OfferKiller AI Agent

An enterprise-grade AI Agent system for personalized resume generation and job application optimization.

## 🎯 Overview

OfferKiller transforms job applications through AI-powered resume optimization, skill gap analysis, and interview preparation. Built with a microservices architecture using Java Spring Boot, Python AI services, and containerized deployment.

## 🏗️ Architecture

### Core Components
- **Backend Services**: Java Spring Boot microservices with Spring Cloud
- **AI Services**: Python-based AI/ML components with Hugging Face
- **Frontend**: Modern web application (bolt.new generated)
- **Infrastructure**: Docker + Kubernetes deployment
- **Workflows**: n8n + Voiceflow automation

### Tech Stack
- **Backend**: Java 17, Spring Boot, Spring Cloud, MyBatis, MySQL
- **AI/ML**: Python, PyTorch, Transformers, Hugging Face, MLflow
- **Data**: MySQL, Redis, RabbitMQ, ChromaDB (Vector DB)
- **Infrastructure**: Docker, Kubernetes, Helm, Terraform
- **Monitoring**: Prometheus, Grafana, OpenTelemetry
- **CI/CD**: GitHub Actions, Docker Registry

## 🚀 Quick Start

### Prerequisites
- Linux VM with Docker and Docker Compose
- At least 8GB RAM and 50GB disk space
- Git configured with GitHub access

### Development Setup
```bash
# Clone repository
git clone git@github.com:yourusername/offerkiller.git
cd offerkiller

# Start development environment
./scripts/start-dev.sh

# Verify services
docker ps
```

### Service URLs
- **API Gateway**: http://localhost:8080
- **AI Services**: http://localhost:8090
- **RabbitMQ Management**: http://localhost:15672
- **Database**: localhost:3306
- **Redis**: localhost:6379
- **ChromaDB**: http://localhost:8000

## 📁 Project Structure

```
offerkiller/
├── backend/                    # Java Spring microservices
├── ai-services/               # Python AI/ML components  
├── frontend/                  # Web application
├── infrastructure/            # Infrastructure as Code
├── workflows/                 # Process automation
├── mlops/                     # MLOps pipelines
├── docker/                    # Container configurations
├── scripts/                   # Utility scripts
├── docs/                      # Documentation
└── tests/                     # Cross-cutting tests
```

## 🔧 Development

### Backend Development
```bash
# Navigate to service
cd backend/user-service

# Run tests
mvn test

# Build
mvn clean package

# Run locally
mvn spring-boot:run
```

### AI Services Development
```bash
# Navigate to AI service
cd ai-services/resume-generator

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest

# Start service
python -m src.main
```

### Frontend Development
```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

## 📚 Documentation

- [Architecture Overview](docs/architecture/README.md)
- [API Documentation](docs/api/README.md)
- [Deployment Guide](docs/deployment/README.md)
- [Development Guide](docs/development/README.md)

## 🧪 Testing

```bash
# Run all tests
./scripts/run-tests.sh

# Run specific test suites
mvn test                    # Backend tests
pytest ai-services/        # AI service tests
npm test                    # Frontend tests
```

## 🚀 Deployment

### Local Development
```bash
./scripts/start-dev.sh
```

### Staging Deployment
```bash
kubectl apply -f infrastructure/kubernetes/environments/staging/
```

### Production Deployment
```bash
# Using Helm
helm upgrade --install offerkiller infrastructure/helm/charts/offerkiller/ \
  --values infrastructure/helm/values/production.yaml
```

## 🔐 Security

- OAuth2/JWT authentication
- RBAC authorization
- PII encryption
- Audit logging
- HTTPS/TLS encryption

## 📊 Monitoring

- **Metrics**: Prometheus + Grafana
- **Logging**: ELK Stack
- **Tracing**: Jaeger
- **Health Checks**: Spring Boot Actuator

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/yourusername/offerkiller/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/offerkiller/discussions)

## 🏷️ Version

Current Version: 1.0.0-alpha

## 📈 Roadmap

- [ ] Core AI agent functionality
- [ ] Advanced analytics dashboard
- [ ] Mobile application
- [ ] Multi-language support
- [ ] Enterprise SSO integration
