#!/usr/bin/env bash
# =============================================================================
# tests/test.sh - Test suite for claude-ac
# =============================================================================
# Run with: bash tests/test.sh
# Or:       bash tests/test.sh --verbose
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$ROOT_DIR/lib"
CONFIG_DIR="$ROOT_DIR/config"
FIXTURES_DIR="$SCRIPT_DIR/.fixtures"

# Source the libraries under test
source "$LIB_DIR/detect.sh"
source "$LIB_DIR/notify.sh"
source "$LIB_DIR/session.sh"
source "$CONFIG_DIR/defaults.sh"

# Disable actual notifications during tests
NOTIFY=0
VERBOSE=0

# ---------------------------------------------------------------------------
# Test framework (zero-dependency, no [[ ]] passed as args)
# ---------------------------------------------------------------------------
_PASS=0; _FAIL=0
VERBOSE_TESTS="${1:-}"

_pass() {
    _PASS=$((_PASS + 1))
    [[ "$VERBOSE_TESTS" == "--verbose" ]] && echo "  [PASS] $1"
    return 0
}

_fail() {
    _FAIL=$((_FAIL + 1))
    echo "  [FAIL] $1"
    [[ -n "${2:-}" ]] && echo "      got:  $2"
    [[ -n "${3:-}" ]] && echo "      want: $3"
    return 0
}

# assert_true <desc> <exit-code>
# Usage: cmd; assert_true "desc" $?
assert_true() {
    local desc="$1" code="${2:-0}"
    [[ "$code" -eq 0 ]] && _pass "$desc" || _fail "$desc"
}

# assert_false <desc> <exit-code>
assert_false() {
    local desc="$1" code="${2:-0}"
    [[ "$code" -ne 0 ]] && _pass "$desc" || _fail "$desc"
}

# assert_eq <desc> <got> <want>
assert_eq() {
    local desc="$1" got="$2" want="$3"
    [[ "$got" == "$want" ]] && _pass "$desc" || _fail "$desc" "'$got'" "'$want'"
}

# assert_numeric <desc> <value>
assert_numeric() {
    local desc="$1" val="$2"
    if [[ "$val" =~ ^[0-9]+$ ]]; then _pass "$desc"; else _fail "$desc" "'$val'" "^[0-9]+$"; fi
}

# assert_gt <desc> <a> <b>  -> asserts a > b
assert_gt() {
    local desc="$1" a="$2" b="$3"
    [[ "$a" -gt "$b" ]] && _pass "$desc" || _fail "$desc" "$a" "> $b"
}

# assert_nonempty <desc> <value>
assert_nonempty() {
    local desc="$1" val="$2"
    [[ -n "$val" ]] && _pass "$desc" || _fail "$desc" "(empty)" "(non-empty)"
}

section() { echo -e "\n\033[1m$*\033[0m"; }

# ---------------------------------------------------------------------------
# Fixtures: simulated Claude Code output files
# ---------------------------------------------------------------------------
setup_fixtures() {
    mkdir -p "$FIXTURES_DIR"

    cat > "$FIXTURES_DIR/credit_limit.txt" <<'EOF'
* Bash(cat src/main.py)
  [output truncated]

* Error: Claude AI usage limit has been reached.
  Your usage will reset at 5:00 PM.
  Please try again later.
EOF

    cat > "$FIXTURES_DIR/rate_limit_429.txt" <<'EOF'
* Read(README.md)
Error: 429 Too Many Requests
rate_limit_error: You have exceeded your rate limit. Retry after 60 seconds.
EOF

    cat > "$FIXTURES_DIR/success.txt" <<'EOF'
* Bash(npm test)
  All tests passed (42/42)
Task completed successfully. All 42 tests pass.
EOF

    cat > "$FIXTURES_DIR/interrupted.txt" <<'EOF'
* Bash(npm run build)
  Building...
Interrupted by user.
EOF

    cat > "$FIXTURES_DIR/overloaded.txt" <<'EOF'
Error: Claude is currently overloaded. Please try again later.
EOF

    cat > "$FIXTURES_DIR/reset_hours.txt" <<'EOF'
Usage limit reached. Your quota resets in 2 hours 30 minutes.
EOF
}

setup_fixtures

# ---------------------------------------------------------------------------
# Tests: should_retry
# ---------------------------------------------------------------------------
# Note: under set -e we use "RC=0; cmd || RC=$?" to safely capture exit codes
# without triggering errexit on expected-false results.
section "should_retry - credit exhaustion detection"

RC=0; should_retry "$FIXTURES_DIR/credit_limit.txt"   1 || RC=$?; assert_true  "detects 'usage limit' pattern"          $RC
RC=0; should_retry "$FIXTURES_DIR/rate_limit_429.txt" 1 || RC=$?; assert_true  "detects 429 / rate_limit_error"         $RC
RC=0; should_retry "$FIXTURES_DIR/overloaded.txt"     1 || RC=$?; assert_true  "detects 'overloaded' pattern"           $RC
RC=0; should_retry "$FIXTURES_DIR/success.txt"        0 || RC=$?; assert_false "does NOT retry on successful completion" $RC
RC=0; should_retry "$FIXTURES_DIR/credit_limit.txt"   0 || RC=$?; assert_false "exit code 0 = never retry"             $RC
RC=0; should_retry "$FIXTURES_DIR/interrupted.txt"    1 || RC=$?; assert_false "user interrupt is not a credit error"  $RC

# Missing file -> should_retry returns 1 for non-existent file
RC=0; should_retry "/tmp/no_such_file_claude_ac_$$" 1 2>/dev/null || RC=$?
assert_false "returns false for missing file" $RC

# ---------------------------------------------------------------------------
# Tests: extract_wait_time
# ---------------------------------------------------------------------------
section "extract_wait_time - reset time parsing"

RESULT=$(extract_wait_time "$FIXTURES_DIR/credit_limit.txt" 999 2>/dev/null || echo "999")
assert_numeric "parses 'reset at HH:MM' -> result is numeric" "$RESULT"

RESULT=$(extract_wait_time "$FIXTURES_DIR/reset_hours.txt" 999 2>/dev/null || echo "999")
assert_numeric "parses 'resets in X hours Y minutes' -> numeric" "$RESULT"
assert_gt "2h30m gives at least 9000 seconds" "$RESULT" 8999

RESULT=$(extract_wait_time "$FIXTURES_DIR/interrupted.txt" 300 2>/dev/null || echo "300")
assert_eq "falls back to default when no time info" "$RESULT" "300"

# ---------------------------------------------------------------------------
# Tests: notify_send (must not crash)
# ---------------------------------------------------------------------------
section "notify_send - no-crash guarantee"

NOTIFY=0
notify_send "Test" "Should be silent" "info"
assert_true "notify_send is a no-op when NOTIFY=0" $?

# ---------------------------------------------------------------------------
# Tests: session state
# ---------------------------------------------------------------------------
section "save / load / clear session state"

CLAUDE_AC_STATE_DIR="/tmp/claude-ac-test-$$"
_START_TIME=$(date +%s)

save_session_state "/tmp/myproject" 3 "abc-session-id"
STATE=$(load_session_state)

echo "$STATE" | grep -q "/tmp/myproject";      assert_true "state contains cwd"          $?
echo "$STATE" | grep -q '"retry_count": 3';    assert_true "state contains retry_count"  $?
echo "$STATE" | grep -q "abc-session-id";      assert_true "state contains session_id"   $?

clear_session_state
AFTER=$(load_session_state)
assert_eq "clear_session_state removes the file" "$AFTER" "{}"

rm -rf "$CLAUDE_AC_STATE_DIR"

# ---------------------------------------------------------------------------
# Tests: format_duration
# ---------------------------------------------------------------------------
section "format_duration"

assert_eq "0 seconds"    "$(format_duration 0)"    "00h 00m 00s"
assert_eq "90 seconds"   "$(format_duration 90)"   "00h 01m 30s"
assert_eq "3661 seconds" "$(format_duration 3661)" "01h 01m 01s"

# ---------------------------------------------------------------------------
# Tests: bash syntax of every script
# ---------------------------------------------------------------------------
section "bash syntax check - all scripts"

bash -n "$ROOT_DIR/bin/claude-ac";         assert_true "bin/claude-ac"         $?
bash -n "$ROOT_DIR/hooks/stop.sh";         assert_true "hooks/stop.sh"         $?
bash -n "$ROOT_DIR/lib/detect.sh";         assert_true "lib/detect.sh"         $?
bash -n "$ROOT_DIR/lib/notify.sh";         assert_true "lib/notify.sh"         $?
bash -n "$ROOT_DIR/lib/session.sh";        assert_true "lib/session.sh"        $?
bash -n "$ROOT_DIR/config/defaults.sh";    assert_true "config/defaults.sh"    $?
bash -n "$ROOT_DIR/install.sh";            assert_true "install.sh"            $?

# ---------------------------------------------------------------------------
# Tests: defaults values
# ---------------------------------------------------------------------------
section "config/defaults.sh - values"

assert_numeric  "DEFAULT_RETRY_INTERVAL is numeric"  "$DEFAULT_RETRY_INTERVAL"
assert_numeric  "DEFAULT_MAX_RETRIES is numeric"      "$DEFAULT_MAX_RETRIES"
assert_gt       "DEFAULT_RETRY_INTERVAL > 0"          "$DEFAULT_RETRY_INTERVAL" 0
assert_gt       "DEFAULT_MAX_RETRIES > 0"             "$DEFAULT_MAX_RETRIES"    0
assert_nonempty "CLAUDE_AC_VERSION is set"            "$CLAUDE_AC_VERSION"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================"
TOTAL=$((_PASS + _FAIL))
echo "  Results: $TOTAL tests - $_PASS passed / $_FAIL failed"
echo "============================================"
echo ""

[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
