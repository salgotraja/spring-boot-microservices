# HashiCorp Vault Setup and Integration Guide

## 1. Install Vault using Helm

Create an installation script `deployment/helm/install-vault.sh`:
```bash
#!/bin/bash

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

cat > deployment/k8s/vault/values.yaml <<EOF
server:
  dev:
    enabled: true
    devRootToken: "root"
  service:
    type: NodePort
ui:
  enabled: true
  serviceType: NodePort
EOF

helm install vault hashicorp/vault \
  --namespace bookstore \
  --values deployment/k8s/vault/values.yaml
```

## 2. Configure Vault Authentication

### 2.1 Create ServiceAccount and RBAC
Create `deployment/k8s/vault/auth.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: bookstore
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault-auth
    namespace: bookstore
```

Apply the configuration:
```bash
kubectl apply -f deployment/k8s/vault/auth.yaml
```

### 2.2 Configure Kubernetes Authentication
Create `deployment/k8s/vault/configure-auth.sh`:
```bash
#!/bin/bash

kubectl exec -it vault-0 -n bookstore -- sh -c '
export VAULT_TOKEN="root"

# Enable kubernetes auth
vault auth enable kubernetes

# Configure kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443" \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt)" \
    issuer="https://kubernetes.default.svc.cluster.local"
'
```

## 3. Configure Vault Policies

### 3.1 Create Policy ConfigMap
Create `deployment/k8s/vault/policy.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-policy
  namespace: bookstore
data:
  policy.hcl: |
    path "secret/data/bookstore/*" {
      capabilities = ["read"]
    }
```

Apply the policy:
```bash
kubectl apply -f deployment/k8s/vault/policy.yaml
```

## 4. Initialize Vault and Store Secrets

Create `deployment/k8s/vault/init-vault.sh`:
```bash
#!/bin/bash

if ! pgrep -f "kubectl port-forward.*vault.*8200:8200" > /dev/null; then
    echo "Starting Vault port-forward..."
    kubectl port-forward -n bookstore svc/vault 8200:8200 &
    PORTAL_PID=$!
    sleep 5
else
    echo "Vault port-forward is already running"
fi

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault --namespace bookstore

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
        echo "✓ Successfully stored secret at: secret/bookstore/$path"
    else
        echo "✗ Failed to store secret at: secret/bookstore/$path"
        exit 1
    fi
}

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
```

## 5. Update Service Deployments

### 5.1 PostgreSQL Databases
Update StatefulSet configurations with Vault annotations:

```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: 'true'
    vault.hashicorp.com/agent-inject-status: 'update'
    vault.hashicorp.com/role: 'app-role'
    vault.hashicorp.com/agent-inject-secret-database: 'secret/bookstore/database'
    vault.hashicorp.com/agent-inject-template-database: |
      {{- with secret "secret/bookstore/database" -}}
      POSTGRES_USER={{ .Data.data.username }}
      POSTGRES_PASSWORD={{ .Data.data.password }}
      {{- end }}
```

### 5.2 RabbitMQ
Add Vault annotations to RabbitMQ deployment:
```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: 'true'
    vault.hashicorp.com/role: 'app-role'
    vault.hashicorp.com/agent-inject-secret-rabbitmq: 'secret/bookstore/rabbitmq'
    vault.hashicorp.com/agent-inject-template-rabbitmq: |
      {{- with secret "secret/bookstore/rabbitmq" -}}
      RABBITMQ_DEFAULT_USER={{ .Data.data.username }}
      RABBITMQ_DEFAULT_PASS={{ .Data.data.password }}
      {{- end }}
```

### 5.3 Keycloak
Update Keycloak deployment with Vault integration:
```yaml
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: 'true'
    vault.hashicorp.com/agent-inject-status: 'update'
    vault.hashicorp.com/role: 'app-role'
    vault.hashicorp.com/agent-inject-secret-keycloak: 'secret/bookstore/keycloak'
    vault.hashicorp.com/agent-inject-template-keycloak: |
      {{- with secret "secret/bookstore/keycloak" -}}
      KEYCLOAK_ADMIN="{{ .Data.data.admin }}"
      KEYCLOAK_ADMIN_PASSWORD="{{ .Data.data.password }}"
      {{- end }}
```

## 6. Verify Setup

1. Check Vault status:
```bash
kubectl get pods -n bookstore -l app.kubernetes.io/name=vault
```

2. Verify secrets:
```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN="root"
vault kv get secret/bookstore/database
vault kv get secret/bookstore/rabbitmq
vault kv get secret/bookstore/keycloak
```

3. Check service pods:
```bash
kubectl get pods -n bookstore
```

## 7. Troubleshooting

1. Check Vault agent logs:
```bash
kubectl logs -n bookstore <pod-name> -c vault-agent-init
```

2. Verify secret injection:
```bash
kubectl exec -it <pod-name> -n bookstore -- cat /vault/secrets/<secret-name>
```

3. Check pod events:
```bash
kubectl describe pod <pod-name> -n bookstore
```

## Notes
- Keep the Vault port-forward running for continued access
- Use `pkill -f 'kubectl port-forward.*vault.*8200:8200'` to stop port-forwarding when needed
- Monitor pod logs for any secret injection issues
- Ensure proper service account and RBAC permissions are in place