#!/bin/bash

set -e

if ! pgrep -f "kubectl port-forward.*vault.*8200:8200" > /dev/null; then
    echo "Starting Vault port-forward..."
    kubectl port-forward -n bookstore svc/vault 8200:8200 &
    PORTAL_PID=$!
    sleep 5
else
    echo "Vault port-forward is already running"
fi

export VAULT_TOKEN="root"
export VAULT_ADDR="http://localhost:8200"

check_vault_connection() {
    vault status >/dev/null 2>&1
    return $?
}

echo "Waiting for Vault to be accessible..."
for i in {1..30}; do
    if check_vault_connection; then
        echo "Vault is accessible"
        break
    fi
    echo "Waiting for Vault to be accessible... attempt $i"
    sleep 2
    if [ $i -eq 30 ]; then
        echo "Timeout waiting for Vault"
        exit 1
    fi
done

store_monitoring_secret() {
    local path=$1
    shift
    echo "Storing secret at: secret/monitoring/$path"
    if vault kv put "secret/monitoring/$path" "$@"; then
        if vault kv get "secret/monitoring/$path" >/dev/null 2>&1; then
            echo "✓ Successfully stored and verified secret at: secret/monitoring/$path"
        else
            echo "✗ Failed to verify secret at: secret/monitoring/$path"
            exit 1
        fi
    else
        echo "✗ Failed to store secret at: secret/monitoring/$path"
        exit 1
    fi
}

verify_vault_config() {
    echo "Verifying Vault configuration for monitoring..."

    if ! vault policy read monitoring-policy >/dev/null 2>&1; then
        echo "✗ monitoring-policy not found"
        return 1
    fi

    if ! vault read auth/kubernetes/role/monitoring-role >/dev/null 2>&1; then
        echo "✗ monitoring-role not found"
        return 1
    fi

    echo "✓ Vault configuration verified"
    return 0
}

if ! verify_vault_config; then
    echo "Vault configuration verification failed. Running configure-auth.sh..."
    bash $(dirname "$0")/configure-auth.sh
fi

store_monitoring_secret "grafana" \
    admin="admin" \
    password="admin123"

# Add more monitoring secrets as needed
#store_monitoring_secret "prometheus" \
#    username="prometheus" \
#    password="prom-pass"
#
#store_monitoring_secret "loki" \
#    username="loki" \
#    password="loki-pass"

echo "Monitoring secrets initialization complete!"
echo "Port-forward is still running in the background. To stop it later, use:"
echo "pkill -f 'kubectl port-forward.*vault.*8200:8200'"