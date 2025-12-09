#!/bin/sh
# Test verification script for common.sh library
# This test validates that all required functions exist and work correctly
# Expected: FAIL (common.sh doesn't exist yet - RED phase of TDD)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_LIB="$SCRIPT_DIR/common.sh"

TEST_PASSED=0
TEST_FAILED=0

# Test helper functions
test_function_exists() {
    local func_name="$1"
    if grep -q "^${func_name}()" "$COMMON_LIB" 2>/dev/null; then
        echo "[PASS] Function $func_name exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        echo "[FAIL] Function $func_name does not exist"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
}

# Test 1: common.sh file exists
echo "Test 1: common.sh file exists"
if [ -f "$COMMON_LIB" ]; then
    echo "[PASS] common.sh exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo "[FAIL] common.sh does not exist at $COMMON_LIB"
    TEST_FAILED=$((TEST_FAILED + 1))
    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Tests passed: $TEST_PASSED"
    echo "Tests failed: $TEST_FAILED"
    exit 1
fi

# Test 2: Required logging functions exist
echo ""
echo "Test 2: Logging functions exist"
test_function_exists "log_info"
test_function_exists "log_error"
test_function_exists "log_warn"
test_function_exists "log_success"

# Test 3: Cleanup functions exist
echo ""
echo "Test 3: Cleanup functions exist"
test_function_exists "cleanup_container"

# Test 4: Wait functions exist
echo ""
echo "Test 4: Wait functions exist"
test_function_exists "wait_for_port"
test_function_exists "wait_for_dns"
test_function_exists "wait_container_stable"

# Test 5: Utility functions exist
echo ""
echo "Test 5: Utility functions exist"
test_function_exists "is_container_running"
test_function_exists "print_summary"

# Test 6: TEST_FAILED global variable exists
echo ""
echo "Test 6: TEST_FAILED global variable exists"
if grep -q "TEST_FAILED=" "$COMMON_LIB" 2>/dev/null; then
    echo "[PASS] TEST_FAILED variable exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo "[FAIL] TEST_FAILED variable does not exist"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Library can be sourced without errors
echo ""
echo "Test 7: Library can be sourced"
if . "$COMMON_LIB" 2>/dev/null; then
    echo "[PASS] common.sh can be sourced"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo "[FAIL] common.sh cannot be sourced (syntax errors)"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 8: Logging functions work
echo ""
echo "Test 8: Logging functions work"
# Run in subshell to avoid TEST_FAILED contamination from log_error
if (. "$COMMON_LIB" 2>/dev/null && \
   log_info "test" >/dev/null 2>&1 && \
   log_error "test" >/dev/null 2>&1 && \
   log_warn "test" >/dev/null 2>&1 && \
   log_success "test" >/dev/null 2>&1); then
    echo "[PASS] Logging functions work"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    echo "[FAIL] Logging functions do not work"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Print summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests passed: $TEST_PASSED"
echo "Tests failed: $TEST_FAILED"

if [ "$TEST_FAILED" -gt 0 ]; then
    exit 1
fi

exit 0
