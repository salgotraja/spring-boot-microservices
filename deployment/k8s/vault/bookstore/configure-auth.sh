#!/bin/bash

set -e

VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"root"}

export VAULT_ADDR
export VAULT_TOKEN

echo "Configuring Vault authentication for bookstore namespace..."

kubectl exec -i vault-0 -n bookstore -- sh << 'EOF'
set -e
export VAULT_TOKEN="root"

echo "Enabling kubernetes auth method..."
vault auth enable kubernetes || true

echo "Configuring kubernetes auth..."
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
    issuer="https://kubernetes.default.svc.cluster.local"

echo "Writing Vault policy..."
cat << POLICY > /tmp/bookstore-policy.hcl
path "secret/data/bookstore/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/bookstore/*" {
  capabilities = ["read", "list"]
}
POLICY

vault policy write bookstore-policy /tmp/bookstore-policy.hcl

echo "Creating kubernetes auth role..."

vault write auth/kubernetes/role/bookstore-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=bookstore \
    policies=bookstore-policy \
    ttl=24h

# Verify configuration
vault read auth/kubernetes/role/bookstore-role

echo "Vault configuration completed for bookstore namespace"
EOF