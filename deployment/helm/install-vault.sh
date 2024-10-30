helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

cat > deployment/k8s/vault/values.yaml <<EOF
global:
  enabled: true

server:
  dev:
    enabled: true
    devRootToken: "root"
  service:
    type: NodePort
  postStart:
    - /bin/sh
    - -c
    - |
      sleep 5
      vault secrets enable -path=secret kv-v2
      vault auth enable kubernetes

ui:
  enabled: true
  serviceType: NodePort

injector:
  enabled: true
EOF

helm install vault hashicorp/vault \
  --namespace bookstore \
  --values deployment/k8s/vault/values.yaml