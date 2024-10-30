#!/bin/bash

kubectl wait --timeout=5m --for=condition=Ready pod -l app.kubernetes.io/name=vault --namespace bookstore

kubectl port-forward -n bookstore svc/vault 8200:8200 &
PORTAL_PID=$!
sleep 5

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN="root"

echo "Configuring Kubernetes auth..."
kubectl exec -i vault-0 -n bookstore -- sh <<'EOF'
export VAULT_TOKEN="root"

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
    issuer="https://kubernetes.default.svc.cluster.local"

# Create bookstore policy
vault policy write app-policy - <<POLICY
path "secret/data/bookstore/*" {
  capabilities = ["read", "list"]
}
path "secret/bookstore/*" {
  capabilities = ["read", "list"]
}
POLICY

# Create monitoring policy
vault policy write monitoring-policy - <<POLICY
path "secret/data/monitoring/*" {
  capabilities = ["read", "list"]
}
POLICY

# Create roles
vault write auth/kubernetes/role/app-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=bookstore \
    policies=app-policy \
    ttl=24h

vault write auth/kubernetes/role/monitoring-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=monitoring \
    policies=monitoring-policy \
    ttl=24h
EOF

echo "Vault basic configuration complete!"