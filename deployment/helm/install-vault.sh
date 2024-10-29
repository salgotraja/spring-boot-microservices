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