#!/bin/bash

VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"root"}

export VAULT_ADDR
export VAULT_TOKEN

echo "Configuring Vault authentication for monitoring namespace..."

kubectl exec -i vault-0 -n bookstore -- sh << 'EOF'
export VAULT_TOKEN="root"

echo "Creating monitoring policy..."

cat << POLICY > /tmp/monitoring-policy.hcl
path "secret/data/monitoring/*" {
  capabilities = ["read", "list"]
}
POLICY

vault policy write monitoring-policy /tmp/monitoring-policy.hcl

echo "Creating kubernetes auth role for monitoring..."

vault write auth/kubernetes/role/monitoring-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=monitoring \
    policies=monitoring-policy \
    ttl=24h

echo "Vault configuration completed for monitoring namespace"
EOF