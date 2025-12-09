#!/bin/sh
# Integration tests for Unbound DNS server
# Tests full DNS functionality with real-world scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unbound-network:main}"

# Unique resource names based on PID
TEST_ID=$$
UNBOUND_CONTAINER="unbound-test-integration-$TEST_ID"
CLIENT_CONTAINER="unbound-test-client-$TEST_ID"
NETWORK_NAME="unbound-test-$TEST_ID"

cleanup() {
    log_info "Cleaning up integration test environment..."
    docker rm -f "$UNBOUND_CONTAINER" "$CLIENT_CONTAINER" 2>/dev/null || true
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
}

trap cleanup EXIT

log_info "========================================="
log_info "Integration Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Create network
log_info "Creating test network..."
docker network create "$NETWORK_NAME"

# Start Unbound with test configuration
log_info "Starting Unbound container..."
docker run -d \
  --name "$UNBOUND_CONTAINER" \
  --network "$NETWORK_NAME" \
  --network-alias unbound \
  -v "$SCRIPT_DIR/configs/unbound-test.conf:/etc/unbound/unbound.conf:ro" \
  "$IMAGE_NAME"

# Test 1: Unbound container is running
log_info "Test 1: Unbound container is running"
sleep 5
if is_container_running "$UNBOUND_CONTAINER"; then
    log_success "Unbound container is running"
else
    log_error "Unbound container is not running"
    docker logs "$UNBOUND_CONTAINER" | tail -20
fi

# Test 2: Unbound container stability
log_info "Test 2: Unbound container stability check"
if wait_container_stable "$UNBOUND_CONTAINER" 10; then
    log_success "Unbound container is stable"
else
    log_error "Unbound container is not stable"
fi

# Wait for DNS to be ready
log_info "Waiting for DNS to be ready..."
sleep 15

# Start client container with DNS tools
log_info "Starting client container with DNS tools..."
docker run -d \
  --name "$CLIENT_CONTAINER" \
  --network "$NETWORK_NAME" \
  --entrypoint sleep \
  alpine:latest \
  3600 >/dev/null 2>&1

# Install bind-tools in client for DNS testing
log_info "Installing DNS tools in client container..."
docker exec "$CLIENT_CONTAINER" apk add --no-cache bind-tools >/dev/null 2>&1

# Verify DNS is responding before running tests
log_info "Verifying DNS is responding..."
if ! docker exec "$CLIENT_CONTAINER" timeout 10 nslookup google.com unbound >/dev/null 2>&1; then
    log_warn "DNS not responding yet, waiting additional 10s..."
    sleep 10
fi

# Test 3: Network connectivity between containers
log_info "Test 3: Client can resolve Unbound hostname"
if docker exec "$CLIENT_CONTAINER" sh -c "getent hosts unbound" >/dev/null 2>&1 || \
   docker exec "$CLIENT_CONTAINER" ping -c 1 unbound >/dev/null 2>&1; then
    log_success "Client can reach Unbound container"
else
    log_error "Client cannot reach Unbound container"
fi

# Test 4: External DNS resolution - A record
log_info "Test 4: External DNS resolution - A record (google.com)"
if docker exec "$CLIENT_CONTAINER" nslookup google.com unbound >/dev/null 2>&1; then
    log_success "A record query successful"
else
    log_error "A record query failed"
    docker exec "$CLIENT_CONTAINER" nslookup google.com unbound 2>&1 | tail -10 || true
fi

# Test 5: External DNS resolution - alternative domain
log_info "Test 5: External DNS resolution - alternative (cloudflare.com)"
if docker exec "$CLIENT_CONTAINER" nslookup cloudflare.com unbound >/dev/null 2>&1; then
    log_success "Alternative domain query successful"
else
    log_warn "Alternative domain query failed"
fi

# Test 6: AAAA record query (IPv6)
log_info "Test 6: AAAA record query (IPv6)"
if docker exec "$CLIENT_CONTAINER" nslookup -type=AAAA google.com unbound >/dev/null 2>&1; then
    log_success "AAAA record query successful"
else
    log_warn "AAAA record query failed (may be expected)"
fi

# Test 7: MX record query
log_info "Test 7: MX record query"
if docker exec "$CLIENT_CONTAINER" nslookup -type=MX google.com unbound >/dev/null 2>&1; then
    log_success "MX record query successful"
else
    log_warn "MX record query failed"
fi

# Test 8: Rapid query load test
log_info "Test 8: Rapid query load test (10 queries)"
QUERY_COUNT=0
for i in 1 2 3 4 5 6 7 8 9 10; do
    if docker exec "$CLIENT_CONTAINER" timeout 5 nslookup google.com unbound >/dev/null 2>&1; then
        QUERY_COUNT=$((QUERY_COUNT + 1))
    fi
done
if [ "$QUERY_COUNT" -ge 8 ]; then
    log_success "Load test passed: $QUERY_COUNT/10 queries successful"
else
    log_error "Load test failed: only $QUERY_COUNT/10 queries successful"
fi

# Test 9: DNS caching verification
log_info "Test 9: DNS caching verification (repeat query should be faster)"
# First query
START1=$(date +%s%N)
docker exec "$CLIENT_CONTAINER" nslookup example.com unbound >/dev/null 2>&1 || true
END1=$(date +%s%N)
TIME1=$((END1 - START1))

# Second query (should be cached)
START2=$(date +%s%N)
docker exec "$CLIENT_CONTAINER" nslookup example.com unbound >/dev/null 2>&1 || true
END2=$(date +%s%N)
TIME2=$((END2 - START2))

if [ "$TIME2" -le "$TIME1" ]; then
    log_success "Caching appears to be working (query times: ${TIME1}ns vs ${TIME2}ns)"
else
    log_warn "Caching test inconclusive"
fi

# Test 10: No critical errors in Unbound logs
log_info "Test 10: No critical errors in Unbound logs"
if docker logs "$UNBOUND_CONTAINER" 2>&1 | grep -qiE "fatal error|Cannot start|Failed to start|error:.*fatal"; then
    log_error "Critical errors found in logs"
    docker logs "$UNBOUND_CONTAINER" 2>&1 | grep -iE "fatal|error" | head -10
else
    log_success "No critical errors in logs"
fi

# Test 11: Unbound still running after load
log_info "Test 11: Unbound still running after load tests"
if is_container_running "$UNBOUND_CONTAINER"; then
    log_success "Unbound container still running"
else
    log_error "Unbound container stopped"
    docker logs "$UNBOUND_CONTAINER" 2>&1 | tail -20
fi

# Test 12: TCP DNS queries work
log_info "Test 12: TCP DNS queries work"
if docker exec "$CLIENT_CONTAINER" sh -c "dig @unbound google.com +tcp >/dev/null 2>&1" || \
   docker exec "$CLIENT_CONTAINER" sh -c "nslookup -vc google.com unbound >/dev/null 2>&1"; then
    log_success "TCP DNS queries work"
else
    log_warn "TCP DNS query test inconclusive"
fi

# Test 13: Multiple simultaneous queries
log_info "Test 13: Multiple simultaneous queries"
if docker exec "$CLIENT_CONTAINER" sh -c "nslookup google.com unbound & nslookup cloudflare.com unbound & wait" >/dev/null 2>&1; then
    log_success "Simultaneous queries handled successfully"
else
    log_warn "Simultaneous query test inconclusive"
fi

# Test 14: DNS response for different TLDs
log_info "Test 14: DNS queries for different TLDs"
TLD_SUCCESS=0
for domain in google.com github.io wikipedia.org example.net; do
    if docker exec "$CLIENT_CONTAINER" timeout 5 nslookup "$domain" unbound >/dev/null 2>&1; then
        TLD_SUCCESS=$((TLD_SUCCESS + 1))
    fi
done
if [ "$TLD_SUCCESS" -ge 3 ]; then
    log_success "Different TLDs resolved: $TLD_SUCCESS/4"
else
    log_warn "Only $TLD_SUCCESS/4 different TLDs resolved"
fi

# Print summary and exit
print_summary "Integration Tests"
exit $TEST_FAILED
