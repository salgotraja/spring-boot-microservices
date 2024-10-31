#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level=$1
    local msg=$2
    local color=$3
    echo -e "${color}$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "Command '$1' not found. Please install it first." "$RED"
        exit 1
    fi
}

check_cluster() {
    if ! kind get clusters 2>/dev/null | grep -q "^kind$"; then
        log "INFO" "Creating new Kind cluster..." "$YELLOW"
        cd deployment/kind && ./create-cluster.sh
        cd ../..
    else
        log "INFO" "Kind cluster already exists" "$YELLOW"
    fi
}

setup_hosts() {
    log "INFO" "Setting up host entries..." "$YELLOW"
    sudo "$(dirname "$0")/manage-hosts.sh" add
}

setup_namespaces() {
    log "INFO" "Creating namespaces..." "$YELLOW"
    kubectl apply -f deployment/k8s/namespace.yaml
    kubectl apply -f deployment/k8s/monitoring/namespace.yaml
}

setup_network_policies() {
    log "INFO" "Applying network policies..." "$YELLOW"
    kubectl apply -f deployment/k8s/network-policies.yaml
}

setup_vault() {
    log "INFO" "Setting up HashiCorp Vault..." "$YELLOW"

    bash deployment/helm/install-vault.sh
    check_previous_step

    log "INFO" "Configuring Vault..." "$YELLOW"
    ./deployment/k8s/vault/setup-all.sh
    check_previous_step

    log "INFO" "Verifying Vault configuration..." "$YELLOW"
    kubectl exec -it vault-0 -n bookstore -- sh -c '
        export VAULT_TOKEN="root"
        vault status && \
        vault auth list && \
        vault policy list && \
        vault read auth/kubernetes/role/bookstore-role && \
        vault read auth/kubernetes/role/monitoring-role
    '
    check_previous_step
}

setup_monitoring() {
    log "INFO" "Setting up monitoring stack..." "$YELLOW"
    kubectl apply -f deployment/k8s/monitoring/prometheus/
    kubectl apply -f deployment/k8s/monitoring/loki/
    kubectl apply -f deployment/k8s/monitoring/tempo/
    kubectl apply -f deployment/k8s/monitoring/grafana/
    kubectl apply -f deployment/k8s/monitoring/promtail/
}

setup_infrastructure() {
    log "INFO" "Setting up infrastructure services..." "$YELLOW"

    kubectl apply -f deployment/k8s/infra/keycloak/
    kubectl wait --for=condition=ready pod -l app=keycloak -n bookstore --timeout=300s

    kubectl apply -f deployment/k8s/infra/postgres/

    kubectl apply -f deployment/k8s/infra/rabbitmq/

    kubectl apply -f deployment/k8s/infra/mailhog/
}

setup_applications() {
    log "INFO" "Deploying applications..." "$YELLOW"
    kubectl apply -f deployment/k8s/apps/api-gateway/
    kubectl apply -f deployment/k8s/apps/catalog-service/
    kubectl apply -f deployment/k8s/apps/order-service/
    kubectl apply -f deployment/k8s/apps/notification-service/
    kubectl apply -f deployment/k8s/apps/bookstore-webapp/
}

setup_ingress() {
    log "INFO" "Configuring ingress..." "$YELLOW"
    kubectl apply -f deployment/k8s/ingress/
}

verify_deployment() {
    log "INFO" "Verifying deployment..." "$YELLOW"

    kubectl wait --for=condition=ready pod --all -n bookstore --timeout=300s
    kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

    log "INFO" "Checking service endpoints..." "$GREEN"
    echo "✓ Bookstore Web Application: http://bookstore.local:8080"
    echo "✓ API Documentation: http://api.bookstore.local:8989/swagger-ui.html"
    echo "✓ Grafana: http://grafana.local:3000"
}

main() {
    log "INFO" "Starting setup process..." "$YELLOW"

    check_command "kind"
    check_command "docker"
    check_command "kubectl"
    check_command "helm"

    check_cluster
    setup_hosts
    setup_namespaces
    setup_network_policies
    setup_vault
    setup_monitoring
    setup_infrastructure
    setup_applications
    setup_ingress
    verify_deployment

    log "SUCCESS" "Setup completed successfully!" "$GREEN"

    echo -e "\n${YELLOW}Access Information:${NC}"
    echo "1. Bookstore Web Application: http://bookstore.local:8080"
    echo "2. API Documentation: http://api.bookstore.local:8989/swagger-ui.html"
    echo "3. Grafana: http://grafana.local:3000 (admin/admin123)"
    echo "4. Use port-forward script to access other services:"
    echo "   ./deployment/scripts/port-forward.sh start"
}

main

exit 0