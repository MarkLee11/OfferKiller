# Backend Services

Java Spring Boot microservices with Spring Cloud ecosystem.

## Services

### 1. User Service (Port 8081)
- User registration and authentication
- Profile management
- OAuth2/JWT token handling

### 2. Job Service (Port 8082)
- Job posting ingestion
- Job description parsing
- Company information management

### 3. AI Orchestration Service (Port 8083)
- AI workflow coordination
- Request routing to Python AI services
- Response aggregation and formatting

### 4. Resume Service (Port 8084)
- Resume storage and versioning
- PDF processing and text extraction
- Resume template management

### 5. API Gateway (Port 8080)
- Request routing and load balancing
- Rate limiting and security
- API documentation (Swagger)

### 6. Shared Libraries
- Common utilities and DTOs
- Database configurations
- Security configurations

## Technology Stack

- **Java**: 17
- **Framework**: Spring Boot 3.2+
- **Microservices**: Spring Cloud 2023.0+
- **Database**: MySQL 8.0 with MyBatis
- **Cache**: Redis 7+
- **Messaging**: RabbitMQ 3.12+
- **Service Discovery**: Nacos
- **Circuit Breaker**: Sentinel
- **Distributed Transactions**: Seata
- **Service Communication**: OpenFeign

## Development Setup

```bash
# Build all services
mvn clean install

# Run specific service
cd user-service
mvn spring-boot:run

# Run tests
mvn test
```

## Configuration

Each service uses Spring profiles:
- `dev`: Development configuration
- `staging`: Staging environment
- `prod`: Production environment

Configuration files located in `src/main/resources/application-{profile}.yml`

## Database Migration

Using Flyway for database versioning:
```bash
mvn flyway:migrate
```

## API Documentation

Swagger UI available at: `http://localhost:8080/swagger-ui.html`

## Monitoring

- Health checks: `/actuator/health`
- Metrics: `/actuator/metrics`
- Info: `/actuator/info`
