#!/bin/bash

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

store_monitoring_secret() {
    local path=$1
    shift
    echo "Storing secret at: secret/monitoring/$path"
    if vault kv put "secret/monitoring/$path" "$@"; then
        echo "✓ Successfully stored secret at: secret/monitoring/$path"
    else
        echo "✗ Failed to store secret at: secret/monitoring/$path"
        exit 1
    fi
}

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