# Spring Boot Microservices: Kubernetes Cluster

## Getting Started

### Prerequisites
- Docker
- Kind (Kubernetes in Docker)
- kubectl

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
  
### Starting the Cluster

1. Create the cluster using the script:
```bash
cd deployment/kind
./create-cluster.sh

```

## Apply configurations in sequence

### Create namespaces first
````
  kubectl apply -f deployment/k8s/namespace.yaml 
  kubectl apply -f deployment/k8s/monitoring/namespace.yaml
````

### Apply Network Policies
````
  kubectl apply -f deployment/k8s/network-policies.yaml
````

### Create secrets
````
  kubectl apply -f deployment/k8s/secrets.yaml
````

### Setup monitoring stack
````
  kubectl apply -f deployment/k8s/monitoring/prometheus/ 
  kubectl apply -f deployment/k8s/monitoring/loki/ 
  kubectl apply -f deployment/k8s/monitoring/tempo/ 
  kubectl apply -f deployment/k8s/monitoring/grafana/ 
  kubectl apply -f deployment/k8s/monitoring/promtail/
````

### Deploy infrastructure services
````
  kubectl apply -f deployment/k8s/infra/keycloak/ 
  kubectl apply -f deployment/k8s/infra/postgres/ 
  kubectl apply -f deployment/k8s/infra/rabbitmq/ 
  kubectl apply -f deployment/k8s/infra/mailhog/
````

### Deploy microservices
````
  kubectl apply -f deployment/k8s/apps/api-gateway/ 
  kubectl apply -f deployment/k8s/apps/catalog-service/ 
  kubectl apply -f deployment/k8s/apps/order-service/ 
  kubectl apply -f deployment/k8s/apps/notification-service/ 
  kubectl apply -f deployment/k8s/apps/bookstore-webapp/
````
### Apply ingress configurations
````
  kubectl apply -f deployment/k8s/ingress/
````
# Application Access
## Main Applications
- Bookstore Web Application: http://bookstore.local:8080
- API Documentation (Swagger): http://api.bookstore.local:8989/swagger-ui.html

### Infrastructure UIs

- Grafana: http://grafana.local:3000 (admin/admin123)
- Prometheus: http://localhost:9090 (via port-forward)
- RabbitMQ Management: http://localhost:15672 (via port-forward)
- Keycloak Admin: http://localhost:9191 (via port-forward)

## Host File Configuration
Add these entries to your /etc/hosts file:
````
127.0.0.1 bookstore.local
127.0.0.1 api.bookstore.local
127.0.0.1 grafana.local
````

## Viewing Service Status

### View all services in bookstore namespace
````
  kubectl get services -n bookstore
````

### Check specific microservices
````
  kubectl get pods -n bookstore -l app=catalog-service
  kubectl get pods -n bookstore -l app=order-service
  kubectl get pods -n bookstore -l app=notification-service
````

## Monitoring Stack Management

### Check monitoring stack status
````
  kubectl get pods -n monitoring
  kubectl get services -n monitoring
````

### Get Grafana URL (if using NodePort)
````
  kubectl get service grafana -n monitoring
  kubectl get ingress -n monitoring
````

### Check Prometheus targets
````
  kubectl port-forward -n monitoring service/prometheus 9090:9090
````
* Then access http://localhost:9090/targets in your browser

### Check Loki logs for specific pod
````
  kubectl logs -f -n monitoring -l app=loki
````

### Fix CrashLoopBackOff Promtail
````
  kubectl describe pod -n monitoring -l app=promtail
  kubectl logs -f -n monitoring -l app=promtail
````

## Database Operations

### Check all statefulsets
````
  kubectl get statefulset -n bookstore
````

### Check database pods
```` 
  kubectl get pods -n bookstore -l app=catalog-db
  kubectl get pods -n bookstore -l app=orders-db
  kubectl get pods -n bookstore -l app=notifications-db
````

### Access database logs
```` 
  kubectl logs -f -n bookstore catalog-db-0
````

## RabbitMQ Management

### Check RabbitMQ status
````
  kubectl get pods -n bookstore -l app=rabbitmq
  kubectl port-forward -n bookstore service/rabbitmq 15672:15672
````

* Access RabbitMQ management UI at http://localhost:15672

## Keycloak Operations

### Check Keycloak status
````
  kubectl get pods -n bookstore -l app=keycloak 
  kubectl port-forward -n bookstore service/keycloak 9191:9191
````

### Get Keycloak logs
````
  kubectl logs -f -n bookstore -l app=keycloak
````

## Ingress Management

### Check ingress status
````
  kubectl get ingress -n bookstore 
  kubectl get pods -n ingress-nginx 
  kubectl describe ingress -n bookstore web-ingress
````

### Get ingress controller logs
````
  kubectl logs -f -n ingress-nginx -l app.kubernetes.io/component=controller
````

## Debugging Commands

Debug network connectivity between services
```` 
  kubectl run -n bookstore test-connection --rm -i --tty --image nicolaka/netshoot -- /bin/bash
````

### Then inside the container:
- curl http://catalog-service:8081/actuator/health
- curl http://order-service:8082/actuator/health
- curl http://keycloak:9191/health

### Check endpoints
````
  kubectl get endpoints -n bookstore catalog-service 
  kubectl get endpoints -n bookstore order-service 
  kubectl get endpoints -n bookstore keycloak
````

## Common Troubleshooting Patterns

### Restart all microservices
````
  kubectl rollout restart deployment -n bookstore catalog-service order-service notification-service api-gateway bookstore-webapp
````

### Check ConfigMaps
````
  kubectl get configmap -n bookstore 
  kubectl describe configmap -n bookstore bookstore-webapp-config
````

### Check Network Policies
````
  kubectl get networkpolicies -n bookstore 
  kubectl get networkpolicies -n monitoring
````

### View service logs in monitoring namespace
````
  kubectl logs -f -n monitoring $(kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')
````

# Troubleshooting

## Common Issues

1. Services Not Starting

````
# Check pod status
kubectl get pods -n bookstore
# Check pod logs
kubectl logs -f -n bookstore <pod-name>
````

2. Ingress Issues

````
# Check ingress controller
kubectl get pods -n ingress-nginx
# Check ingress configuration
kubectl describe ingress -n bookstore web-ingress
````

3. Database Connection Issues

```
# Check database pods
kubectl get pods -n bookstore | grep db
# Check database logs
kubectl logs -f -n bookstore <db-pod-name>
```

# Cleaning Up

```
cd deployment/kind
./destroy-cluster.sh
```