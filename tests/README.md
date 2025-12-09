# Test Suite Documentation

Comprehensive testing framework for docker-unbound with three test suites validating image structure, runtime behavior, and DNS functionality.

## Test Configuration

Tests use a custom Unbound configuration (`tests/configs/unbound-test.conf`) that enables:
- Listening on all interfaces (0.0.0.0 and ::0)
- Access from Docker private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

**Security Note**: The published image uses the default secure configuration (localhost only). Test configuration is only mounted during test execution.

## Test Suites

### Structure Tests (`structure.sh`)

Validates Docker image structure without running the container.

**Tests (14 total):**
- DNS ports exposed (53/tcp, 53/udp)
- Unbound binary and utilities exist
- Package installation verified
- Version extraction works
- Configuration directories present
- No cache files left behind
- Image size reasonable (<50MB)
- Base image is Alpine
- Required dependencies installed

**Usage:**
```bash
make test-structure
./tests/structure.sh unbound-network:main
```

### Standalone Tests (`standalone.sh`)

Tests container runtime behavior and DNS service functionality.

**Tests (12 total):**
- Container stability
- Unbound process running
- DNS ports listening (TCP/UDP)
- Startup logs show success
- No critical errors
- Configuration validates
- DNS query resolution works internally
- unbound-control available
- Container stays running
- DNS responds from host
- Process flags correct

**Usage:**
```bash
make test-standalone
./tests/standalone.sh unbound-network:main
```

### Integration Tests (`integration.sh`)

Full DNS functionality testing with multi-container scenarios.

**Tests (14 total):**
- Container stability in network
- External DNS resolution (A, AAAA, MX records)
- Network connectivity between containers
- Rapid query load testing (10 queries)
- DNS caching verification
- TCP DNS queries
- Simultaneous queries
- Multiple TLD resolution
- No errors in logs after load

**Usage:**
```bash
make test-integration
./tests/integration.sh unbound-network:main
```

## Running Tests

### All Tests
```bash
make test-all
```

### Individual Suites
```bash
make test-structure
make test-standalone
make test-integration
```

### Cleanup
```bash
make clean-test
```

## Test Library

Shared test utilities in `tests/lib/common.sh`:

**Logging Functions:**
- `log_info(message)` - Informational messages
- `log_error(message)` - Errors (sets TEST_FAILED=1)
- `log_warn(message)` - Warnings
- `log_success(message)` - Success messages

**Cleanup Functions:**
- `cleanup_container(name)` - Safe container removal
- `is_container_running(name)` - Check container status

**Wait Functions:**
- `wait_container_stable(name, seconds)` - Wait for container stability
- `wait_for_port(host, port, protocol, max_wait)` - Wait for port availability
- `wait_for_dns(server, port, domain, max_wait)` - Wait for DNS response

**DNS Testing:**
- `test_dns_query(server, port, domain, type)` - Test DNS query

**Utilities:**
- `print_summary(suite_name)` - Print test results

## Writing New Tests

### Test Structure

```bash
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

IMAGE_NAME="${1:-unbound-network:main}"
CONTAINER_NAME="unbound-test-mytest-$$"

cleanup() {
    cleanup_container "$CONTAINER_NAME"
}

trap cleanup EXIT

# Start container
docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME"

# Run tests
log_info "Test 1: Description"
if [ condition ]; then
    log_success "Test passed"
else
    log_error "Test failed"
fi

# Print summary
print_summary "My Test Suite"
exit $TEST_FAILED
```

### Best Practices

1. **Use unique container names**: Append `$$` (PID) to avoid conflicts
2. **Always cleanup**: Use trap to ensure cleanup on exit
3. **Set errexit**: Use `set -e` for early exit on errors
4. **Log clearly**: Use appropriate log levels
5. **Test one thing**: Each test should validate a single aspect
6. **Handle timing**: Use wait functions for async operations
7. **Alpine compatibility**: Use POSIX sh syntax, not bash

## Troubleshooting

### Tests Fail Locally

1. **Check Docker daemon**: `docker ps`
2. **Rebuild image**: `make build`
3. **Clean test resources**: `make clean-test`
4. **Check logs**: Add `-x` to test script shebang for debugging

### DNS Resolution Fails

1. **Check network**: Verify Docker network connectivity
2. **Check DNS tools**: Ensure `bind-tools` package available
3. **Check timing**: Increase wait times if DNS takes longer to start
4. **Check firewall**: Verify port 53 not blocked

### Container Exits Immediately

1. **Check configuration**: Run `unbound-checkconf` in container
2. **Check logs**: `docker logs <container>`
3. **Check entrypoint**: Verify Unbound starts in foreground mode (-d)

## CI/CD Integration

Tests run automatically in GitHub Actions:

```yaml
- name: Run tests
  run: make test-all
```

All three suites must pass for builds to succeed.

## Performance

Typical execution times:
- Structure tests: ~5 seconds
- Standalone tests: ~20 seconds
- Integration tests: ~40 seconds
- Total: ~65 seconds

## Future Enhancements

Potential test additions:
- DNSSEC validation testing
- Performance/load testing
- Custom zone configuration testing
- Upstream DNS failover testing
