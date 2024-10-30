#!/bin/bash

VAULT_ADDR=${VAULT_ADDR:-"http://localhost:8200"}
VAULT_TOKEN=${VAULT_TOKEN:-"root"}

export VAULT_ADDR
export VAULT_TOKEN

echo "Configuring Vault authentication for bookstore namespace..."

kubectl exec -i vault-0 -n bookstore -- sh << 'EOF'
# Set Vault environment variables inside pod
export VAULT_TOKEN="root"

echo "Enabling kubernetes auth method..."
# Enable kubernetes auth if not already enabled
if ! vault auth list | grep -q kubernetes; then
    vault auth enable kubernetes
fi

echo "Configuring kubernetes auth..."
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
    issuer="https://kubernetes.default.svc.cluster.local"

echo "Writing Vault policy..."
cat << POLICY > /tmp/policy.hcl
path "secret/data/bookstore/*" {
  capabilities = ["read"]
}
POLICY

vault policy write app-policy /tmp/policy.hcl

echo "Creating kubernetes auth role..."

vault write auth/kubernetes/role/app-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=bookstore \
    policies=app-policy \
    ttl=1h

echo "Vault configuration completed for bookstore namespace"
EOF