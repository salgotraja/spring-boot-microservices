#!/bin/bash

# Run this command first
# shellcheck disable=SC2016
kubectl exec -it vault-0 -n bookstore -- sh -c
export VAULT_TOKEN="root"

# Enable kubernetes auth
vault auth enable kubernetes

# Configure kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
    issuer="https://kubernetes.default.svc.cluster.local"

# Create policy
cat << EOF > /tmp/policy.hcl
path "secret/data/bookstore/*" {
  capabilities = ["read"]
}
EOF

vault policy write app-policy /tmp/policy.hcl

vault write auth/kubernetes/role/app-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=bookstore \
    policies=app-policy \
    ttl=1h
