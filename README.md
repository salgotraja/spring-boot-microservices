# Spring Boot Microservices Demonstration Project

## Overview
This project demonstrates a modern microservices architecture implementation using Spring Boot,
showcasing best practices in microservices design, security, monitoring, and deployment.
It implements a bookstore application with distributed services, secure authentication,
asynchronous messaging, and comprehensive monitoring.

## Project Highlights
- Complete microservices architecture implementation
- Both Docker Compose and Kubernetes deployment options
- Secured with Keycloak authentication
- Event-driven architecture using RabbitMQ
- Centralized secrets management with HashiCorp Vault
- Comprehensive monitoring and tracing setup
- API documentation with Swagger
- Local Kubernetes development using Kind


## Architecture Components

### Core Microservices
- **Catalog Service** (Port: 8081)
  - Manages book inventory
  - Handles product catalog operations
  - PostgreSQL database for persistence

- **Order Service** (Port: 8082)
  - Processes customer orders
  - Manages order lifecycle
  - PostgreSQL database for order storage

- **Notification Service** (Port: 8083)
  - Handles email notifications
  - Processes events from RabbitMQ
  - Uses MailHog for email testing
  - PostgreSQL database for notification tracking

- **Bookstore WebApp** (Port: 8080)
  - Frontend application
  - User interface for customers
  - Secured with Keycloak

- **API Gateway** (Port: 8989)
  - Central entry point for all services
  - Request routing and load balancing
  - Swagger API documentation

### Infrastructure Services
- **Keycloak** (Port: 9191): Authentication and authorization
- **RabbitMQ** (Ports: 5672, 15672): Message broker for async communication
- **PostgreSQL** (Port: 5432): Database for all services
- **HashiCorp Vault** (Port: 8200): Secrets management
- **MailHog**: Email testing service

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Metrics visualization
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing
- **Promtail**: Log collection

## Key Features
- **Authentication & Authorization**
  - Keycloak integration
  - JWT token-based security
  - Role-based access control

- **Event-Driven Architecture**
  - Asynchronous communication via RabbitMQ
  - Event-based notifications
  - Decoupled service design

- **API Documentation**
  - Swagger UI integration
  - Interactive API testing
  - Comprehensive endpoint documentation

- **Monitoring & Observability**
  - Distributed tracing
  - Centralized logging
  - Metrics visualization
  - Performance monitoring

- **DevOps Ready**
  - Kubernetes manifests
  - Docker Compose setup
  - Secret management
  - Infrastructure as Code

## Development Environment
The project uses Kind (Kubernetes in Docker) for local development,
providing a lightweight yet fully functional Kubernetes environment.
This ensures that local development closely matches production deployments while maintaining ease of use.

## Getting Started

### Prerequisites
- Docker
- Kind (Kubernetes in Docker)
- kubectl
- Helm (for HashiCorp Vault installation)

# Service Architecture

## Microservices

- API Gateway (Port: 8989)
  - Routes requests to appropriate services
  - Handles API documentation

- Bookstore WebApp (Port: 8080)
  - Frontend application
  - Secured with Keycloak

- Catalog Service (Port: 8081)
  - Manages book catalog
  - PostgreSQL database

- Order Service (Port: 8082)
  - Handles order processing
  - PostgreSQL database

- Notification Service (Port: 8083)
  - Manages notifications
  - PostgreSQL database

## Infrastructure Services

- HashiCorp Vault (Port: 8200)
  - Secrets management
  - Credentials for all services

- Keycloak (Port: 9191)
  - Authentication and authorization

- RabbitMQ (Port: 5672, Management: 15672)
  - Message broker

- PostgreSQL (Port: 5432)
  - Database for services

## Monitoring Stack

- Prometheus (Port: 9090)
  - Metrics collection

- Grafana (Port: 3000)
  - Metrics visualization

- Loki (Port: 3100)
  - Log aggregation

- Tempo (Port: 3200, Zipkin: 9411)
  - Distributed tracing

- Promtail
  - Log collection agent

# Deployment Guide

## 1. Starting the Cluster

Create the cluster using the script:
```bash
cd deployment/kind
./create-cluster.sh
```

## 2. Apply Configurations in Sequence

### 2.1 Create namespaces
```bash
kubectl apply -f deployment/k8s/namespace.yaml 
kubectl apply -f deployment/k8s/monitoring/namespace.yaml
```

### 2.2 Apply Network Policies
```bash
kubectl apply -f deployment/k8s/network-policies.yaml
```

### 2.3 Setup HashiCorp Vault
```bash
cd deployment/helm
./install-vault.sh

./deployment/k8s/vault/setup-all.sh

kubectl get pods -n bookstore -l app.kubernetes.io/name=vault

```

### 2.4 Setup monitoring stack
```bash
kubectl apply -f deployment/k8s/monitoring/prometheus/ 
kubectl apply -f deployment/k8s/monitoring/loki/ 
kubectl apply -f deployment/k8s/monitoring/tempo/ 
kubectl apply -f deployment/k8s/monitoring/grafana/ 
kubectl apply -f deployment/k8s/monitoring/promtail/
```

### 2.5 Deploy infrastructure services
```bash
kubectl apply -f deployment/k8s/infra/keycloak/ 
kubectl apply -f deployment/k8s/infra/postgres/ 
kubectl apply -f deployment/k8s/infra/rabbitmq/ 
kubectl apply -f deployment/k8s/infra/mailhog/
```

### 2.6 Deploy microservices
```bash
kubectl apply -f deployment/k8s/apps/api-gateway/ 
kubectl apply -f deployment/k8s/apps/catalog-service/ 
kubectl apply -f deployment/k8s/apps/order-service/ 
kubectl apply -f deployment/k8s/apps/notification-service/ 
kubectl apply -f deployment/k8s/apps/bookstore-webapp/
```

### 2.7 Apply ingress configurations
```bash
kubectl apply -f deployment/k8s/ingress/
```

# Application Access

## Main Applications
- Bookstore Web Application: http://bookstore.local:8080
- API Documentation (Swagger): http://api.bookstore.local:8989/swagger-ui.html

## Infrastructure UIs
- HashiCorp Vault UI: http://localhost:8200 (Token: root)
- Grafana: http://grafana.local:3000 (admin/admin123)
- Prometheus: http://localhost:9090 (via port-forward)
- RabbitMQ Management: http://localhost:15672 (via port-forward)
- Keycloak Admin: http://localhost:9191 (via port-forward)
- Mailhog: http://localhost:8025/ (via port-forward)

## Host File Configuration
Add these entries to your /etc/hosts file:
```
127.0.0.1 bookstore.local
127.0.0.1 api.bookstore.local
127.0.0.1 grafana.local
```

# Operations Guide

## HashiCorp Vault Operations

### Check Vault status and access
```bash
kubectl get pods -n bookstore -l app.kubernetes.io/name=vault

kubectl port-forward -n bookstore svc/vault 8200:8200 &

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="root"

vault auth list
vault secrets list

vault kv get secret/bookstore/database
vault kv get secret/bookstore/rabbitmq
vault kv get secret/bookstore/keycloak
vault kv get secret/monitoring/grafana
```

## Service Status Management

### View services and pods
```bash
kubectl get services -n bookstore

kubectl get pods -n bookstore -l app=catalog-service
kubectl get pods -n bookstore -l app=order-service
kubectl get pods -n bookstore -l app=notification-service
```

## Database Operations

### Monitor database instances
```bash
kubectl get statefulset -n bookstore

kubectl get pods -n bookstore -l app=catalog-db
kubectl get pods -n bookstore -l app=orders-db
kubectl get pods -n bookstore -l app=notifications-db

kubectl logs -f -n bookstore catalog-db-0
```

## RabbitMQ Management
```bash
kubectl get pods -n bookstore -l app=rabbitmq

kubectl port-forward -n bookstore service/rabbitmq 15672:15672 &
```

## Keycloak Operations
```bash
kubectl get pods -n bookstore -l app=keycloak 
kubectl port-forward -n bookstore service/keycloak 9191:9191 &

kubectl logs -f -n bookstore -l app=keycloak
```

## Monitoring Stack Management
```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring

kubectl port-forward -n monitoring service/prometheus 9090:9090 &

kubectl logs -f -n monitoring -l app=loki
```

# Troubleshooting Guide

## Vault-specific Issues

### 1. Secret Injection Issues
```bash
kubectl logs -n bookstore <pod-name> -c vault-agent-init

kubectl describe pod -n bookstore <pod-name>
```

### 2. Vault Authentication Issues
```bash
kubectl get serviceaccount vault-auth -n bookstore

kubectl get clusterrolebinding role-tokenreview-binding
```

## General Issues

### 1. Service Connection Issues
```bash
kubectl run -n bookstore test-connection --rm -i --tty --image nicolaka/netshoot -- /bin/bash

curl http://catalog-service:8081/actuator/health
curl http://order-service:8082/actuator/health
curl http://keycloak:9191/health
```

### 2. Pod Issues
```bash
kubectl get pods -n bookstore
kubectl describe pod -n bookstore <pod-name>
kubectl logs -f -n bookstore <pod-name>
```

### 3. Restart Services
```bash
kubectl rollout restart deployment -n bookstore catalog-service order-service notification-service api-gateway bookstore-webapp
```

# Cleaning Up

```bash
pkill -f 'kubectl port-forward.*vault.*8200:8200'

# Destroy cluster
cd deployment/kind
./destroy-cluster.sh
```

# Security Notes
- Don't commit Vault initialization scripts in repository
- Keep Vault token secure
- Add to .gitignore:
  ```
  deployment/k8s/vault/init-vault.sh
  deployment/k8s/vault/values.yaml
  ```