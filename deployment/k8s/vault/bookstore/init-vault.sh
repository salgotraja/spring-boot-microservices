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

if ! vault secrets list | grep -q "^secret/"; then
    vault secrets enable -path=secret kv-v2
    echo "KV secrets engine enabled"
else
    echo "KV secrets engine already enabled"
fi

store_secret() {
    local path=$1
    shift
    echo "Storing secret at: secret/bookstore/$path"
    if vault kv put "secret/bookstore/$path" "$@"; then
        if vault kv get "secret/bookstore/$path" >/dev/null 2>&1; then
            echo "✓ Successfully stored and verified secret at: secret/bookstore/$path"
        else
            echo "✗ Failed to verify secret at: secret/bookstore/$path"
            exit 1
        fi
    else
        echo "✗ Failed to store secret at: secret/bookstore/$path"
        exit 1
    fi
}

# Verify Vault is configured properly for the namespace
verify_vault_config() {
    echo "Verifying Vault configuration for bookstore..."

    # Verify policy exists
    if ! vault policy read bookstore-policy >/dev/null 2>&1; then
        echo "✗ bookstore-policy not found"
        return 1
    fi

    # Verify role exists
    if ! vault read auth/kubernetes/role/bookstore-role >/dev/null 2>&1; then
        echo "✗ bookstore-role not found"
        return 1
    fi

    echo "✓ Vault configuration verified"
    return 0
}

if ! verify_vault_config; then
    echo "Vault configuration verification failed. Running configure-auth.sh..."
    bash $(dirname "$0")/configure-auth.sh
fi

store_secret "database" \
    username="postgres" \
    password="postgres"

store_secret "rabbitmq" \
    username="guest" \
    password="guest"

store_secret "keycloak" \
    admin="admin" \
    password="admin1234"

echo "Vault initialization complete!"
echo "Port-forward is still running in the background. To stop it later, use:"
echo "pkill -f 'kubectl port-forward.*vault.*8200:8200'"