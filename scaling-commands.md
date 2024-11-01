# Kubernetes Pod Scaling Guide

## 1. Manual Scaling

### 1.1 Scale Individual Deployments
```bash
# Scale a single deployment
kubectl scale deployment api-gateway --replicas=3 -n bookstore
kubectl scale deployment catalog-service --replicas=3 -n bookstore
kubectl scale deployment order-service --replicas=3 -n bookstore
kubectl scale deployment notification-service --replicas=3 -n bookstore
kubectl scale deployment bookstore-webapp --replicas=3 -n bookstore

# Scale StatefulSets
kubectl scale statefulset catalog-db --replicas=2 -n bookstore
kubectl scale statefulset orders-db --replicas=2 -n bookstore
kubectl scale statefulset notifications-db --replicas=2 -n bookstore
```

### 1.2 Batch Scaling Script
```bash
#!/bin/bash

# Scale all microservices to desired replicas
scale_microservices() {
    local replicas=$1
    echo "Scaling all microservices to $replicas replicas..."
    
    deployments=(
        "api-gateway"
        "bookstore-webapp"
        "catalog-service"
        "order-service"
        "notification-service"
    )
    
    for deployment in "${deployments[@]}"; do
        echo "Scaling $deployment to $replicas replicas..."
        kubectl scale deployment "$deployment" --replicas="$replicas" -n bookstore
    done
}

# Scale infrastructure services
scale_infrastructure() {
    local replicas=$1
    echo "Scaling infrastructure services to $replicas replicas..."
    
    infra_deployments=(
        "rabbitmq"
        "mailhog"
        "keycloak"
    )
    
    for deployment in "${infra_deployments[@]}"; do
        echo "Scaling $deployment to $replicas replicas..."
        kubectl scale deployment "$deployment" --replicas="$replicas" -n bookstore
    done
}

# Usage example:
# ./scale.sh microservices 3
# ./scale.sh infrastructure 2

case "$1" in
    "microservices")
        scale_microservices "$2"
        ;;
    "infrastructure")
        scale_infrastructure "$2"
        ;;
    "all")
        scale_microservices "$2"
        scale_infrastructure "$2"
        ;;
    *)
        echo "Usage: $0 {microservices|infrastructure|all} number_of_replicas"
        exit 1
        ;;
esac
```

## 2. Horizontal Pod Autoscaling (HPA)

### 2.1 Create HPAs for Services
```yaml
# hpa-config.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: bookstore
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: catalog-service-hpa
  namespace: bookstore
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog-service
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
# Repeat for other services
```

### 2.2 Apply and Manage HPAs
```bash
# Apply HPA configurations
kubectl apply -f hpa-config.yaml

# Check HPA status
kubectl get hpa -n bookstore

# Delete HPAs if needed
kubectl delete hpa -n bookstore --all
```

## 3. Monitoring Scaling Operations

### 3.1 Watch Pod Scaling
```bash
# Watch pods during scaling
kubectl get pods -n bookstore -w

# Check deployment status
kubectl rollout status deployment/api-gateway -n bookstore
```

### 3.2 Check Resource Usage
```bash
# Get resource usage for pods
kubectl top pods -n bookstore

# Get resource usage for nodes
kubectl top nodes
```

## 4. Quick Reference Commands

### 4.1 Scale All Deployments in Namespace
```bash
# Scale all deployments in bookstore namespace
kubectl get deployments -n bookstore -o name | xargs -I {} kubectl scale {} --replicas=3 -n bookstore

# Scale all deployments in monitoring namespace
kubectl get deployments -n monitoring -o name | xargs -I {} kubectl scale {} --replicas=2 -n monitoring
```

### 4.2 Emergency Scale Down
```bash
# Scale down all deployments to 1 replica
kubectl get deployments -n bookstore -o name | xargs -I {} kubectl scale {} --replicas=1 -n bookstore
```

### 4.3 Check Scaling Status
```bash
# Get all resources that support scaling
kubectl get deployments,statefulsets,hpa -n bookstore

# Get detailed deployment info
kubectl describe deployments -n bookstore
```

## 5. Best Practices for Scaling

1. **Resource Requirements**
   - Ensure proper resource requests and limits are set
   - Monitor resource usage before scaling

2. **Database Considerations**
   - Be cautious when scaling stateful applications
   - Consider connection pooling settings

3. **Load Testing**
   - Test application behavior under different scaling scenarios
   - Monitor application performance metrics

4. **Network Policies**
   - Update network policies if needed for scaled pods
   - Check service discovery and DNS resolution

Would you like me to:
1. Create specific scaling configurations for your services?
2. Add more monitoring configurations for scaled pods?
3. Create a detailed HPA configuration for specific services?
4. Add load testing scripts to verify scaling?