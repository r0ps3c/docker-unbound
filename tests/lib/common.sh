#!/bin/sh
# Common test utilities for docker-unbound
# POSIX sh compatible (Alpine busybox)
# No color codes - CI/CD friendly output

# Global test status flag
TEST_FAILED=0

# Logging functions
log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*"
    TEST_FAILED=1
}

log_warn() {
    echo "[WARN] $*"
}

log_success() {
    echo "[OK] $*"
}

# Container cleanup function
cleanup_container() {
    local container_name="$1"
    if [ -n "$container_name" ]; then
        log_info "Cleaning up container: $container_name"
        docker rm -f "$container_name" 2>/dev/null || true
    fi
}

# Check if container is running
is_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Wait for container to be stable (not restarting)
wait_container_stable() {
    local container_name="$1"
    local wait_seconds="${2:-10}"

    log_info "Waiting ${wait_seconds}s for container stability..."
    sleep "$wait_seconds"

    if is_container_running "$container_name"; then
        return 0
    else
        return 1
    fi
}

# Wait for TCP/UDP port to be listening
wait_for_port() {
    local host="$1"
    local port="$2"
    local protocol="${3:-tcp}"
    local max_wait="${4:-30}"

    log_info "Waiting for $protocol port $port on $host (max ${max_wait}s)..."

    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if [ "$protocol" = "tcp" ]; then
            if nc -z -w 1 "$host" "$port" 2>/dev/null; then
                log_info "Port $port is available"
                return 0
            fi
        else
            # UDP check - try to connect
            if nc -zu -w 1 "$host" "$port" 2>/dev/null; then
                log_info "UDP port $port is available"
                return 0
            fi
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_info "Port $port not available after ${max_wait}s"
    return 1
}

# Wait for DNS to respond
wait_for_dns() {
    local dns_server="$1"
    local dns_port="${2:-53}"
    local test_domain="${3:-google.com}"
    local max_wait="${4:-30}"

    log_info "Waiting for DNS at $dns_server:$dns_port (max ${max_wait}s)..."

    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        # Try nslookup with timeout
        if timeout 5 nslookup "$test_domain" "$dns_server" -port="$dns_port" >/dev/null 2>&1; then
            log_info "DNS is responding"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_info "DNS not responding after ${max_wait}s"
    return 1
}

# Test DNS query
test_dns_query() {
    local dns_server="$1"
    local dns_port="${2:-53}"
    local domain="$3"
    local record_type="${4:-A}"

    if [ "$record_type" = "A" ] || [ "$record_type" = "AAAA" ]; then
        timeout 10 nslookup -type="$record_type" "$domain" "$dns_server" -port="$dns_port" >/dev/null 2>&1
    else
        timeout 10 nslookup -type="$record_type" "$domain" "$dns_server" -port="$dns_port" >/dev/null 2>&1
    fi
}

# Print test summary
print_summary() {
    local test_suite_name="$1"
    echo ""
    echo "========================================="
    echo "$test_suite_name Summary"
    echo "========================================="
    if [ "$TEST_FAILED" -eq 0 ]; then
        log_success "All tests passed"
    else
        log_error "Some tests failed"
    fi
    echo ""
}
