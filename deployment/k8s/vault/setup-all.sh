#!/bin/bash

export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="root"

check_namespace() {
    local namespace=$1
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
    fi
}

setup_port_forward() {
    if ! pgrep -f "kubectl port-forward.*vault.*8200:8200" > /dev/null; then
        echo "Starting Vault port-forward..."
        kubectl port-forward -n bookstore svc/vault 8200:8200 &
        sleep 5
    else
        echo "Vault port-forward is already running"
    fi
}

wait_for_vault() {
    echo "Waiting for Vault to be accessible..."
    for i in {1..30}; do
        if vault status >/dev/null 2>&1; then
            echo "Vault is accessible"
            return 0
        fi
        echo "Waiting for Vault to be accessible... attempt $i"
        sleep 2
    done
    echo "Timeout waiting for Vault"
    return 1
}

setup_namespace() {
    local namespace=$1
    local config_dir="deployment/k8s/vault/$namespace"

    echo "Setting up Vault configuration for $namespace namespace"

    kubectl apply -f "$config_dir/auth.yaml"
    kubectl apply -f "$config_dir/policy.yaml"

    bash "$config_dir/configure-auth.sh"

    bash "$config_dir/init-vault.sh"
}

main() {
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --namespace bookstore

    setup_port_forward

    wait_for_vault || exit 1

    if ! vault secrets list | grep -q "^secret/"; then
        vault secrets enable -path=secret kv-v2
        echo "KV secrets engine enabled"
    fi

    setup_namespace "bookstore"
    setup_namespace "monitoring"

    echo "Vault configuration complete for all namespaces!"
    echo "Note: Port-forward is running in background. To stop it:"
    echo "pkill -f 'kubectl port-forward.*vault.*8200:8200'"
}

main