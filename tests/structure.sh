#!/bin/sh
# Structure tests for Unbound Docker image
# Pure POSIX sh implementation - no external dependencies
# Tests: ports, file existence, packages, base image

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unbound-network:main}"
CONTAINER_NAME="unbound-test-structure-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

log_info "========================================="
log_info "Structure Tests for $IMAGE_NAME"
log_info "========================================="
echo ""

# Start container for inspection (override entrypoint for sleep)
log_info "Starting container for structure inspection..."
docker run -d --name "$CONTAINER_NAME" --entrypoint sleep "$IMAGE_NAME" 3600 >/dev/null 2>&1

# Test 1: DNS ports exposed (53/tcp and 53/udp)
log_info "Test 1: Image exposes DNS ports (53/tcp, 53/udp)"
EXPOSED_PORTS=$(docker inspect "$IMAGE_NAME" --format='{{json .Config.ExposedPorts}}' 2>/dev/null || echo "")
if echo "$EXPOSED_PORTS" | grep -q "53/tcp" && echo "$EXPOSED_PORTS" | grep -q "53/udp"; then
    log_success "DNS ports 53/tcp and 53/udp are exposed"
else
    log_error "Expected DNS ports not exposed: $EXPOSED_PORTS"
fi

# Test 2: Unbound binary exists
log_info "Test 2: Unbound binary exists at /usr/sbin/unbound"
if docker exec "$CONTAINER_NAME" test -f /usr/sbin/unbound; then
    log_success "Unbound binary exists"
else
    log_error "Unbound binary not found"
fi

# Test 3: unbound-checkconf utility exists
log_info "Test 3: unbound-checkconf utility exists"
if docker exec "$CONTAINER_NAME" test -f /usr/sbin/unbound-checkconf; then
    log_success "unbound-checkconf utility exists"
else
    log_error "unbound-checkconf utility not found"
fi

# Test 4: unbound-control utility exists
log_info "Test 4: unbound-control utility exists"
if docker exec "$CONTAINER_NAME" test -f /usr/sbin/unbound-control; then
    log_success "unbound-control utility exists"
else
    log_error "unbound-control utility not found"
fi

# Test 5: Unbound package installed
log_info "Test 5: Unbound package installed"
if docker exec "$CONTAINER_NAME" apk info unbound 2>/dev/null | grep -q "^unbound-"; then
    log_success "Unbound package is installed"
else
    log_error "Unbound package is not installed"
fi

# Test 6: Version extractable and valid format
log_info "Test 6: Unbound version extractable and valid semver format"
VERSION=$(docker exec "$CONTAINER_NAME" sh -c "apk info unbound 2>/dev/null | grep '^unbound-' | sed 's/^unbound-//' | sed 's/-r.*$//'")
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    log_success "Version is extractable and valid: $VERSION"
else
    log_error "Version format invalid: $VERSION"
fi

# Test 7: Config directory exists
log_info "Test 7: Unbound config directory exists"
if docker exec "$CONTAINER_NAME" test -d /etc/unbound; then
    log_success "Config directory /etc/unbound exists"
else
    log_error "Config directory /etc/unbound does not exist"
fi

# Test 8: Root hints file exists (for DNS resolution)
log_info "Test 8: Root hints file exists"
if docker exec "$CONTAINER_NAME" test -f /usr/share/dnssec-root/trusted-key.key; then
    log_success "DNSSEC root key exists"
else
    log_warn "DNSSEC root key not found (may be optional)"
fi

# Test 9: No APK cache files left behind
log_info "Test 9: No APK cache files left in /var/cache/apk"
CACHE_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /var/cache/apk 2>&1 | wc -l' 2>/dev/null || echo "1")
if [ "$CACHE_COUNT" = "0" ]; then
    log_success "No APK cache files"
else
    log_warn "Found $CACHE_COUNT items in /var/cache/apk (may be expected)"
fi

# Test 10: Image size is reasonable (<50MB)
log_info "Test 10: Image size is reasonable"
IMAGE_SIZE=$(docker inspect "$IMAGE_NAME" --format='{{.Size}}' 2>/dev/null || echo "0")
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
if [ "$IMAGE_SIZE_MB" -lt 50 ]; then
    log_success "Image size is $IMAGE_SIZE_MB MB (< 50MB)"
else
    log_warn "Image size is $IMAGE_SIZE_MB MB (larger than expected)"
fi

# Test 11: Base image is Alpine
log_info "Test 11: Base image is Alpine Linux"
if docker exec "$CONTAINER_NAME" cat /etc/os-release 2>/dev/null | grep -q "Alpine"; then
    log_success "Base image is Alpine Linux"
else
    log_error "Base image is not Alpine Linux"
fi

# Test 12: Unbound binary is executable
log_info "Test 12: Unbound binary is executable"
if docker exec "$CONTAINER_NAME" test -x /usr/sbin/unbound; then
    log_success "Unbound binary is executable"
else
    log_error "Unbound binary is not executable"
fi

# Test 13: Check for required dependencies
log_info "Test 13: Required runtime dependencies installed"
DEPS_OK=true
for pkg in libevent dnssec-root; do
    if docker exec "$CONTAINER_NAME" apk info "$pkg" 2>/dev/null | grep -q "^${pkg}-"; then
        log_success "Dependency $pkg is installed"
    else
        log_error "Dependency $pkg is missing"
        DEPS_OK=false
    fi
done

# Test 14: No temporary files in /tmp
log_info "Test 14: No temporary files left in /tmp"
TMP_COUNT=$(docker exec "$CONTAINER_NAME" sh -c 'ls /tmp 2>&1 | wc -l' 2>/dev/null || echo "1")
if [ "$TMP_COUNT" = "0" ]; then
    log_success "No temporary files in /tmp"
else
    log_warn "Found $TMP_COUNT items in /tmp (may be expected)"
fi

# Print summary and exit
print_summary "Structure Tests"
exit $TEST_FAILED
