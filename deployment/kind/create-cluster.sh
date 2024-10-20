#!/bin/bash

set -e

echo "Initializing Kubernetes cluster..."

kind create cluster --name bookstore --config kind-config.yaml

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Creating namespaces..."
kubectl create namespace bookstore
kubectl create namespace monitoring
kubectl create namespace ingress-nginx

echo "\n-----------------------------------------------------\n"

echo "Installing NGINX Ingress..."

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "\n-----------------------------------------------------\n"

echo "Waiting for NGINX Ingress to be ready..."

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "\n"

echo "Happy Sailing!"