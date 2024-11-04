#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_DIR="${PROJECT_ROOT}/deployment/logs/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/setup.log"
PROGRESS_FILE="${LOG_DIR}/progress.txt"

DEBUG=0
ROLLBACK=0
TOTAL_STEPS=8
CURRENT_STEP=0
KUBECTL_TIMEOUT=120s
EXTENDED_TIMEOUT=600s

trap 'cleanup' EXIT

log() {
   local level=$1
   local msg=$2
   local color=$3
   local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
   echo -e "${color}${timestamp} [$level] $msg${NC}" | tee -a "${LOG_FILE}"
}

update_progress() {
   if [ $CURRENT_STEP -lt $TOTAL_STEPS ]; then
       CURRENT_STEP=$((CURRENT_STEP + 1))
       local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
       log "INFO" "Progress: ${percentage}% (Step ${CURRENT_STEP}/${TOTAL_STEPS})" "$CYAN"
       echo "${CURRENT_STEP}" > "${PROGRESS_FILE}"
   fi
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "Script failed - check logs for details" "$RED"

        if [ -f "${SCRIPT_DIR}/port-forward.sh" ]; then
            log "INFO" "Cleaning up port forwards..." "$YELLOW"
            "${SCRIPT_DIR}/port-forward.sh" stop || true
        fi
    fi
}

rollback() {
   local failed_step=$1
   log "WARN" "Rolling back after failure in step: $failed_step" "$YELLOW"

   case $failed_step in
       "vault-install")
           helm uninstall vault -n bookstore || true
           ;;
       "monitoring-"*)
           component=${failed_step#monitoring-}
           kubectl delete -f "${PROJECT_ROOT}/deployment/k8s/monitoring/${component}/" || true
           ;;
       "infra-"*)
           component=${failed_step#infra-}
           kubectl delete -f "${PROJECT_ROOT}/deployment/k8s/infra/${component}/" || true
           ;;
       *)
           log "WARN" "No rollback defined for step: $failed_step" "$YELLOW"
           ;;
   esac
}

check_previous_step() {
   local step_name=$1
   if [ $? -ne 0 ]; then
       log "ERROR" "Step '$step_name' failed" "$RED"
       if [ $ROLLBACK -eq 1 ]; then
           rollback "$step_name"
       fi
       exit 1
   fi
   update_progress
}

wait_for_pods() {
   local namespace=$1
   local label=$2
   local timeout=$3
   local retries=3
   local retry=0

   while [ $retry -lt $retries ]; do
       if kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=$timeout 2>/dev/null; then
           return 0
       fi
       retry=$((retry + 1))
       log "WARN" "Retry $retry/$retries waiting for $label pods in $namespace" "$YELLOW"
       sleep 10
   done
   return 1
}

verify_prerequisites() {
   log "INFO" "Verifying prerequisites..." "$BLUE"
   local required_commands=("kind" "docker" "kubectl" "helm")

   for cmd in "${required_commands[@]}"; do
       if ! command -v "$cmd" &> /dev/null; then
           log "ERROR" "Required command not found: $cmd" "$RED"
           exit 1
       fi
   done
}

check_cluster() {
   if ! kind get clusters 2>/dev/null | grep -q "^bookstore$"; then
       log "INFO" "Creating new Kind cluster..." "$YELLOW"
       cd "${PROJECT_ROOT}/deployment/kind" && ./create-cluster.sh
       check_previous_step "cluster-creation"
       cd "${PROJECT_ROOT}"
       log "INFO" "Waiting for cluster to be fully ready..." "$YELLOW"
       sleep 30
   else
       log "INFO" "Kind cluster already exists" "$YELLOW"
   fi
}

setup_base_infrastructure() {
   log "INFO" "Setting up base infrastructure..." "$YELLOW"

   kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/namespace.yaml"
   kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/monitoring/namespace.yaml"
   check_previous_step "namespaces"

   log "INFO" "Configuring NGINX Ingress..." "$YELLOW"
   kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/ingress/nginx-config.yaml"
   check_previous_step "nginx-config"

   log "INFO" "Waiting for NGINX Ingress Controller..." "$YELLOW"
   wait_for_pods "ingress-nginx" "app.kubernetes.io/component=controller" "${KUBECTL_TIMEOUT}"
   check_previous_step "nginx-controller"
}

setup_vault() {
    log "INFO" "Setting up HashiCorp Vault..." "$YELLOW"

    pkill -f "kubectl port-forward.*vault.*8200:8200" || true
    sleep 2

    bash "${PROJECT_ROOT}/deployment/helm/install-vault.sh"
    check_previous_step "vault-helm-install"

    log "INFO" "Waiting for Vault StatefulSet..." "$YELLOW"
    local retries=6
    local retry=0
    while [ $retry -lt $retries ]; do
        if kubectl get statefulset vault -n bookstore 2>/dev/null; then
            break
        fi
        retry=$((retry + 1))
        log "INFO" "Waiting for Vault StatefulSet to be created (${retry}/${retries})..." "$YELLOW"
        sleep 10
    done

    if [ $retry -eq $retries ]; then
        log "ERROR" "Vault StatefulSet was not created" "$RED"
        exit 1
    fi

    log "INFO" "Waiting for Vault pod to be ready..." "$YELLOW"
    local pod_retries=6
    local pod_retry=0
    local success=false

    while [ $pod_retry -lt $pod_retries ]; do
        if kubectl -n bookstore get pod vault-0 2>/dev/null; then
            if kubectl wait --for=condition=ready pod vault-0 -n bookstore --timeout=${KUBECTL_TIMEOUT}; then
                success=true
                break
            fi
        fi
        pod_retry=$((pod_retry + 1))
        if [ $pod_retry -lt $pod_retries ]; then
            log "INFO" "Waiting for Vault pod to be ready (${pod_retry}/${pod_retries})..." "$YELLOW"
            sleep 20
        fi
    done

    if [ "$success" = false ]; then
        log "ERROR" "Failed to initialize Vault after $pod_retries attempts" "$RED"
        kubectl describe pod vault-0 -n bookstore
        exit 1
    fi

    log "INFO" "Vault pod is ready" "$GREEN"

    log "INFO" "Configuring Vault..." "$YELLOW"
    bash "${PROJECT_ROOT}/deployment/k8s/vault/setup-all.sh"
    check_previous_step "vault-config"
}

setup_monitoring() {
   log "INFO" "Setting up monitoring stack..." "$YELLOW"
   local components=("prometheus" "loki" "tempo" "grafana" "promtail")

   for component in "${components[@]}"; do
       log "INFO" "Deploying ${component}..." "$BLUE"
       kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/monitoring/${component}/"
       wait_for_pods "monitoring" "app=${component}" "${KUBECTL_TIMEOUT}"
       check_previous_step "monitoring-${component}"
   done
}

setup_infrastructure() {
   log "INFO" "Setting up infrastructure services..." "$YELLOW"

   local components=("keycloak" "postgres" "rabbitmq" "mailhog")
   for component in "${components[@]}"; do
       log "INFO" "Deploying ${component}..." "$BLUE"
       kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/infra/${component}/"
       wait_for_pods "bookstore" "app=${component}" "${EXTENDED_TIMEOUT}"
       check_previous_step "infra-${component}"
   done
}

setup_applications() {
   log "INFO" "Deploying applications..." "$YELLOW"
   local apps=("api-gateway" "catalog-service" "order-service" "notification-service" "bookstore-webapp")

   for app in "${apps[@]}"; do
       log "INFO" "Deploying ${app}..." "$BLUE"
       kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/apps/${app}/"
       wait_for_pods "bookstore" "app=${app}" "${EXTENDED_TIMEOUT}"
       check_previous_step "${app}"
   done
}

setup_ingress() {
   log "INFO" "Configuring ingress routes..." "$YELLOW"

   kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/ingress/api-ingress.yaml"
   check_previous_step "api-ingress"

   kubectl apply -f "${PROJECT_ROOT}/deployment/k8s/ingress/web-ingress.yaml"
   check_previous_step "web-ingress"
}

verify_deployment() {
   log "INFO" "Verifying deployment..." "$YELLOW"

   log "INFO" "Pod status in bookstore namespace:" "$BLUE"
   kubectl get pods -n bookstore

   local total_pods=$(kubectl get pods -n bookstore --no-headers | wc -l)
   local ready_pods=$(kubectl get pods -n bookstore --no-headers | grep "Running\|Completed" | wc -l)
   log "INFO" "Bookstore namespace: ${ready_pods}/${total_pods} pods ready" "$BLUE"

   log "INFO" "Pod status in monitoring namespace:" "$BLUE"
   kubectl get pods -n monitoring

   total_pods=$(kubectl get pods -n monitoring --no-headers | wc -l)
   ready_pods=$(kubectl get pods -n monitoring --no-headers | grep "Running\|Completed" | wc -l)
   log "INFO" "Monitoring namespace: ${ready_pods}/${total_pods} pods ready" "$BLUE"

   if [ -f "${SCRIPT_DIR}/port-forward.sh" ]; then
       log "INFO" "Verifying port forwards..." "$BLUE"
       "${SCRIPT_DIR}/port-forward.sh" status
   fi
}

forward_port() {
  if [ -f "${SCRIPT_DIR}/port-forward.sh" ]; then
       log "INFO" "Starting port forwarding..." "$YELLOW"
       "${SCRIPT_DIR}/port-forward.sh" stop &>/dev/null || true
       sleep 2
       if ! "${SCRIPT_DIR}/port-forward.sh" start; then
           log "WARN" "Port forwarding failed but continuing..." "$YELLOW"
       fi
   fi
}

main() {
   mkdir -p "${LOG_DIR}"
   exec &> >(tee -a "${LOG_FILE}")

   log "INFO" "Starting setup process..." "$YELLOW"

   verify_prerequisites
   check_cluster
   setup_base_infrastructure
   setup_vault
   setup_monitoring
   setup_infrastructure
   setup_applications
   setup_ingress
   verify_deployment

   forward_port

   log "SUCCESS" "Setup completed successfully!" "$GREEN"

   echo -e "\n${YELLOW}Access Information:${NC}"
   echo "1. Bookstore Web Application: http://bookstore.local:8080"
   echo "2. API Documentation: http://api.bookstore.local:8989/swagger-ui.html"
   echo "3. Grafana: http://grafana.local:3000 [admin/admin123]"
}

main "$@"

exit 0