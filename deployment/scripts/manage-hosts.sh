#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HOSTS=(
    "bookstore.local"
    "api.bookstore.local"
    "grafana.local"
)

log() {
    local level=$1
    local msg=$2
    local color=$3
    echo -e "${color}$(date '+%Y-%m-%d %H:%M:%S') [$level] $msg${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "Please run as root or with sudo" "$RED"
        exit 1
    fi
}

backup_hosts() {
    local backup_file="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/hosts "$backup_file"
    log "INFO" "Hosts file backed up to $backup_file" "$GREEN"
}

add_hosts() {
    log "INFO" "Adding host entries..." "$YELLOW"
    backup_hosts

    local changed=false
    for host in "${HOSTS[@]}"; do
        if ! grep -q "127.0.0.1 $host" /etc/hosts; then
            echo "127.0.0.1 $host" >> /etc/hosts
            log "INFO" "Added entry for $host" "$GREEN"
            changed=true
        else
            log "INFO" "Entry for $host already exists" "$YELLOW"
        fi
    done

    if [ "$changed" = true ]; then
        log "SUCCESS" "Host entries added successfully" "$GREEN"
    else
        log "INFO" "No new entries needed" "$YELLOW"
    fi
}

remove_hosts() {
    log "INFO" "Removing host entries..." "$YELLOW"
    backup_hosts

    local changed=false
    for host in "${HOSTS[@]}"; do
        if grep -q "127.0.0.1 $host" /etc/hosts; then
            sed -i "/127.0.0.1 $host/d" /etc/hosts
            log "INFO" "Removed entry for $host" "$GREEN"
            changed=true
        else
            log "INFO" "No entry found for $host" "$YELLOW"
        fi
    done

    if [ "$changed" = true ]; then
        log "SUCCESS" "Host entries removed successfully" "$GREEN"
    else
        log "INFO" "No entries to remove" "$YELLOW"
    fi
}

show_hosts() {
    log "INFO" "Current host entries:" "$YELLOW"
    echo -e "${GREEN}"
    for host in "${HOSTS[@]}"; do
        grep "127.0.0.1 $host" /etc/hosts || echo "No entry for $host"
    done
    echo -e "${NC}"
}

main() {
    check_root

    case "$1" in
        add)
            add_hosts
            ;;
        remove)
            remove_hosts
            ;;
        show)
            show_hosts
            ;;
        *)
            echo "Usage: $0 {add|remove|show}"
            echo "  add    - Add host entries"
            echo "  remove - Remove host entries"
            echo "  show   - Show current entries"
            exit 1
            ;;
    esac
}

main "$@"