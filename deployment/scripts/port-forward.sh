#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PID_FILE="/tmp/bookstore-port-forward.pid"

check_port() {
    local port=$1
    if lsof -i :$port > /dev/null; then
        echo 1
    else
        echo 0
    fi
}

start_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local description=$5

    if [ $(check_port $local_port) -eq 1 ]; then
        echo -e "${YELLOW}Port $local_port is already in use. Skipping $service...${NC}"
        return
    fi

    echo -e "${GREEN}Starting port-forward for $service (Port $local_port -> $remote_port)${NC}"
    kubectl port-forward -n $namespace svc/$service $local_port:$remote_port > /dev/null 2>&1 &
    local pid=$!
    echo "$service:$pid" >> $PID_FILE
    echo -e "${GREEN}✓ $description available at http://localhost:$local_port${NC}"
}

stop_port_forward() {
    if [ -f $PID_FILE ]; then
        echo -e "${YELLOW}Stopping all port-forwarding processes...${NC}"
        while IFS=: read -r service pid; do
            if kill -0 $pid 2>/dev/null; then
                kill $pid
                echo -e "${GREEN}✓ Stopped $service (PID: $pid)${NC}"
            fi
        done < $PID_FILE
        rm $PID_FILE
    else
        echo -e "${YELLOW}No port-forwarding processes found.${NC}"
    fi
}

check_status() {
    if [ -f $PID_FILE ]; then
        echo -e "${GREEN}Active port forwards:${NC}"
        while IFS=: read -r service pid; do
            if kill -0 $pid 2>/dev/null; then
                echo -e "${GREEN}✓ $service (PID: $pid) is running${NC}"
            else
                echo -e "${RED}✗ $service (PID: $pid) is not running${NC}"
            fi
        done < $PID_FILE
    else
        echo -e "${YELLOW}No port-forwarding processes found.${NC}"
    fi
}

show_help() {
    echo "Usage: $0 [start|stop|status]"
    echo
    echo "Commands:"
    echo "  start   Start port forwarding for all services"
    echo "  stop    Stop all port forwarding processes"
    echo "  status  Check status of port forwarding processes"
    echo
    echo "Services that will be port forwarded:"
    echo "- Prometheus (9090)"
    echo "- RabbitMQ Management (15672)"
    echo "- Keycloak Admin (9191)"
    echo "- Mailhog (8025)"
    echo "- Vault UI (8200)"
    echo
    echo "Note: Some services like Grafana and the Bookstore Web Application"
    echo "should be accessed through their configured ingress URLs."
}

case "$1" in
    start)
        rm -f $PID_FILE
        touch $PID_FILE

        start_port_forward "prometheus" "monitoring" 9090 9090 "Prometheus"
        start_port_forward "grafana" "monitoring" 3000 3000 "Prometheus"
        start_port_forward "bookstore-rabbitmq" "bookstore" 15672 15672 "RabbitMQ Management UI"
        start_port_forward "keycloak" "bookstore" 9191 9191 "Keycloak Admin Console"
        start_port_forward "mailhog" "bookstore" 8025 8025 "Mailhog UI"
        start_port_forward "vault" "bookstore" 8200 8200 "Vault UI"

        echo -e "\n${GREEN}All port forwards started successfully!${NC}"
        echo -e "${YELLOW}Other services available via ingress:${NC}"
        echo -e "- Grafana: http://grafana.local:3000"
        echo -e "- Bookstore Web App: http://bookstore.local:8080"
        echo -e "- API Documentation: http://api.bookstore.local:8989/swagger-ui.html"
        ;;

    stop)
        stop_port_forward
        ;;

    status)
        check_status
        ;;

    *)
        show_help
        exit 1
        ;;
esac

exit 0