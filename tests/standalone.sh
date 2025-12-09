#!/bin/sh
# Standalone runtime tests for Unbound container
# Tests basic container functionality without external dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unbound-network:main}"
CONTAINER_NAME="unbound-test-standalone-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Standalone Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container with test configuration
log_info "Starting Unbound container in standalone mode..."
if docker run -d --name "$CONTAINER_NAME" \
    -p 15353:53/udp \
    -v "$SCRIPT_DIR/configs/unbound-test.conf:/etc/unbound/unbound.conf:ro" \
    "$IMAGE_NAME"; then
    log_success "Container started successfully"
else
    log_error "Container failed to start"
    exit 1
fi

# Test 1: Container stays running
log_info "Test 1: Container stability check"
if wait_container_stable "$CONTAINER_NAME" 10; then
    log_success "Container is stable and running"
else
    log_error "Container is not stable"
fi

# Test 2: Unbound process is running
log_info "Test 2: Unbound process is running"
if docker exec "$CONTAINER_NAME" ps aux | grep -v grep | grep -q unbound; then
    log_success "Unbound process is running"
else
    log_error "Unbound process is not running"
    docker exec "$CONTAINER_NAME" ps aux || true
fi

# Test 3: DNS port 53 is listening (UDP)
log_info "Test 3: DNS UDP port 53 is listening"
sleep 5
if docker exec "$CONTAINER_NAME" sh -c "netstat -uln 2>/dev/null | grep -q ':53'" || \
   docker exec "$CONTAINER_NAME" sh -c "ss -uln 2>/dev/null | grep -q ':53'"; then
    log_success "DNS UDP port 53 is listening"
else
    log_error "DNS UDP port 53 is not listening"
    docker exec "$CONTAINER_NAME" sh -c "netstat -uln 2>/dev/null || ss -uln 2>/dev/null || echo 'No netstat/ss available'" || true
fi

# Test 4: DNS port 53 is listening (TCP)
log_info "Test 4: DNS TCP port 53 is listening"
if docker exec "$CONTAINER_NAME" sh -c "netstat -tln 2>/dev/null | grep -q ':53'" || \
   docker exec "$CONTAINER_NAME" sh -c "ss -tln 2>/dev/null | grep -q ':53'"; then
    log_success "DNS TCP port 53 is listening"
else
    log_error "DNS TCP port 53 is not listening"
fi

# Test 5: Unbound started successfully (check logs)
log_info "Test 5: Unbound startup logs show success"
sleep 2
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "start|init|ready|listening"; then
    log_success "Unbound startup detected in logs"
else
    log_warn "Could not confirm Unbound startup from logs"
    docker logs "$CONTAINER_NAME" 2>&1 | head -20
fi

# Test 6: No critical errors in logs
log_info "Test 6: No critical errors in logs"
if docker logs "$CONTAINER_NAME" 2>&1 | grep -qiE "fatal error|Cannot start|Failed to start|error:.*fatal"; then
    log_error "Critical errors found in logs"
    docker logs "$CONTAINER_NAME" 2>&1 | grep -iE "fatal|error" | head -10
else
    log_success "No critical errors in logs"
fi

# Test 7: Configuration validates
log_info "Test 7: Unbound configuration is valid"
if docker exec "$CONTAINER_NAME" unbound-checkconf >/dev/null 2>&1; then
    log_success "Configuration is valid"
else
    log_error "Configuration validation failed"
    docker exec "$CONTAINER_NAME" unbound-checkconf 2>&1 || true
fi

# Test 8: DNS query resolution works (internal test)
log_info "Test 8: DNS query resolution works (localhost test)"
sleep 5
if docker exec "$CONTAINER_NAME" sh -c "nslookup google.com 127.0.0.1 >/dev/null 2>&1" || \
   docker exec "$CONTAINER_NAME" sh -c "nslookup cloudflare.com 127.0.0.1 >/dev/null 2>&1"; then
    log_success "DNS resolution works internally"
else
    log_warn "DNS resolution test inconclusive"
fi

# Test 9: unbound-control is available
log_info "Test 9: unbound-control utility is available"
if docker exec "$CONTAINER_NAME" which unbound-control >/dev/null 2>&1; then
    log_success "unbound-control is available"
else
    log_error "unbound-control is not available"
fi

# Test 10: Container still running after all tests
log_info "Test 10: Container still running"
if is_container_running "$CONTAINER_NAME"; then
    log_success "Container still running after all tests"
else
    log_error "Container stopped during tests"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -30
fi

# Test 11: DNS responds to queries from host
log_info "Test 11: DNS responds to queries from host (port 15353)"
if timeout 10 nslookup google.com 127.0.0.1 -port=15353 >/dev/null 2>&1 || \
   timeout 10 nslookup cloudflare.com 127.0.0.1 -port=15353 >/dev/null 2>&1; then
    log_success "DNS responds to queries from host"
else
    log_warn "DNS query from host failed (may need nslookup installed)"
fi

# Test 12: Check Unbound process details
log_info "Test 12: Unbound process running with correct flags"
if docker exec "$CONTAINER_NAME" ps aux | grep -v grep | grep unbound | grep -q -- "-d"; then
    log_success "Unbound running in foreground mode (-d)"
else
    log_warn "Unbound flags may differ from expected"
    docker exec "$CONTAINER_NAME" ps aux | grep unbound | grep -v grep || true
fi

# Print summary and exit
print_summary "Standalone Tests"
exit $TEST_FAILED
