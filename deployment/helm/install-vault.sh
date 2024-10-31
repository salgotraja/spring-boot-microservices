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

check_error() {
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed: $1" "$RED"
        exit 1
    fi
}

log "INFO" "Adding HashiCorp Helm repository..." "$YELLOW"
helm repo add hashicorp https://helm.releases.hashicorp.com
check_error "Failed to add Helm repository"

log "INFO" "Updating Helm repositories..." "$YELLOW"
helm repo update
check_error "Failed to update Helm repositories"

log "INFO" "Creating Vault values configuration..." "$YELLOW"
mkdir -p deployment/k8s/vault
cat > deployment/k8s/vault/values.yaml <<EOF
global:
  enabled: true

server:
  dev:
    enabled: true
    devRootToken: "root"
  service:
    type: NodePort
  postStart:
    - /bin/sh
    - -c
    - |
      sleep 10
      until vault status > /dev/null 2>&1; do
        echo "Waiting for Vault to become ready..."
        sleep 2
      done
      vault secrets enable -path=secret kv-v2 || true
      vault auth enable kubernetes || true

ui:
  enabled: true
  serviceType: NodePort

injector:
  enabled: true
EOF
check_error "Failed to create values.yaml"

log "INFO" "Installing Vault..." "$YELLOW"
helm install vault hashicorp/vault \
  --namespace bookstore \
  --create-namespace \
  --values deployment/k8s/vault/values.yaml
check_error "Failed to install Vault"

log "INFO" "Waiting for Vault pod to be ready..." "$YELLOW"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --namespace bookstore --timeout=300s
check_error "Vault pod failed to become ready"

log "INFO" "Verifying Vault installation..." "$YELLOW"
kubectl get pods -n bookstore -l app.kubernetes.io/name=vault
check_error "Failed to get Vault pod status"

log "SUCCESS" "Vault installation completed successfully" "$GREEN"