#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    local level=$1
    local msg=$2
    local color=$3
    echo -e "${color}$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "Command '$1' not found. Please install it first." "$RED"
        exit 1
    fi
}

cleanup_port_forwards() {
    if [ -f "${SCRIPT_DIR}/port-forward.sh" ]; then
        log "INFO" "Cleaning up port forwards..." "$YELLOW"
        "${SCRIPT_DIR}/port-forward.sh" stop || true
    fi
}

remove_kind_cluster() {
    log "INFO" "Removing Kind cluster..." "$YELLOW"
    if kind delete cluster --name bookstore 2>/dev/null; then
        log "INFO" "Kind cluster deleted successfully" "$GREEN"
    else
        log "WARN" "No Kind cluster found or error deleting cluster" "$YELLOW"
    fi
}

cleanup_docker() {
    log "INFO" "Cleaning up Docker resources..." "$YELLOW"
    docker ps -a | grep 'bookstore-' | awk '{print $1}' | xargs -r docker rm -f
    docker images | grep 'bookstore-' | awk '{print $3}' | xargs -r docker rmi -f
    log "INFO" "Docker cleanup completed" "$GREEN"
}

cleanup_kubectl_config() {
    log "INFO" "Cleaning kubectl configuration..." "$YELLOW"
    kubectl config unset contexts.kind-kind 2>/dev/null || true
    kubectl config unset clusters.kind-kind 2>/dev/null || true
    kubectl config unset users.kind-kind 2>/dev/null || true
    if [ "$(kubectl config current-context 2>/dev/null)" = "kind-kind" ]; then
        kubectl config unset current-context
    fi
    log "INFO" "Kubectl configuration cleaned" "$GREEN"
}

cleanup_temp_files() {
    log "INFO" "Cleaning temporary files..." "$YELLOW"
    rm -f /tmp/vault-portforward.pid 2>/dev/null || true
    rm -f /tmp/bookstore-port-forward.pid 2>/dev/null || true
    log "INFO" "Temporary files cleaned" "$GREEN"
}

cleanup_hosts() {
    log "INFO" "Checking /etc/hosts entries..." "$YELLOW"
    if [ "$EUID" -eq 0 ]; then
        cp /etc/hosts /etc/hosts.bak
        sed -i '/bookstore.local/d' /etc/hosts
        sed -i '/api.bookstore.local/d' /etc/hosts
        sed -i '/grafana.local/d' /etc/hosts
        log "INFO" "Removed local domain entries from /etc/hosts" "$GREEN"
    else
        log "WARN" "Not running as root. Please manually remove entries from /etc/hosts:" "$YELLOW"
        echo "127.0.0.1 bookstore.local"
        echo "127.0.0.1 api.bookstore.local"
        echo "127.0.0.1 grafana.local"
    fi
}

main() {
    check_command "kind"
    check_command "docker"
    check_command "kubectl"

    log "INFO" "Starting cleanup process..." "$YELLOW"

    cleanup_port_forwards
    remove_kind_cluster
    cleanup_docker
    cleanup_kubectl_config
    cleanup_temp_files
    cleanup_hosts

    log "SUCCESS" "Cleanup completed successfully!" "$GREEN"

    echo -e "\n${YELLOW}Additional manual steps that might be needed:${NC}"
    echo "1. Remove entries from /etc/hosts if not already done"
    echo "2. Clear browser cache if experiencing any web access issues"
    echo "3. Remove any personal configurations in ~/.kube/config if needed"
}

main

exit 0