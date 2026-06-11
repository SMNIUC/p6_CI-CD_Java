#!/usr/bin/env bash
#
# run-tests.sh — Run the project's test suite and collect the reports.
#
# It runs the test command documented in the README (`./gradlew clean test`),
# then copies the generated JUnit reports into the local "test-results/" folder.
#
# Before running it verifies the required dependencies are present, cleans up
# any artifacts from a previous run, and propagates the test exit code so that
# CI / callers can detect failures.

# Fail on unset variables and on errors in pipelines.
set -uo pipefail

# Always operate from the directory this script lives in (the project root),
# regardless of where it is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Where Gradle writes the JUnit XML reports, and where we collect them.
GRADLE_RESULTS_DIR="build/test-results/test"
GRADLE_HTML_REPORT_DIR="build/reports/tests/test"
OUTPUT_DIR="test-results"

log()  { printf '\033[1;34m[run-tests]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[run-tests]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[run-tests]\033[0m %s\n' "$*" >&2; }

# ------------------------------------------------------------------
# 1. Verify required dependencies
# ------------------------------------------------------------------
log "Checking required dependencies..."

# The Gradle wrapper must be present and executable.
if [[ ! -f "./gradlew" ]]; then
    err "Gradle wrapper (./gradlew) not found in $SCRIPT_DIR."
    exit 1
fi
if [[ ! -x "./gradlew" ]]; then
    warn "./gradlew is not executable — fixing permissions."
    chmod +x ./gradlew
fi

# A Java runtime is required to run Gradle and the tests.
if ! command -v java >/dev/null 2>&1; then
    err "Java is not installed or not on PATH. JDK 21 is required (see README)."
    exit 1
fi

# Surface the detected Java version (informational; build enforces toolchain).
JAVA_VERSION="$(java -version 2>&1 | head -n 1)"
log "Found Java: ${JAVA_VERSION}"

# ------------------------------------------------------------------
# 2. Clean up artifacts from a previous run
# ------------------------------------------------------------------
log "Cleaning up previous test artifacts..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ------------------------------------------------------------------
# 3. Run the tests (command from the README)
# ------------------------------------------------------------------
log "Running tests: ./gradlew clean test"
./gradlew clean test
TEST_EXIT_CODE=$?

# ------------------------------------------------------------------
# 4. Collect the reports into test-results/
# ------------------------------------------------------------------
if [[ -d "$GRADLE_RESULTS_DIR" ]]; then
    log "Collecting JUnit XML reports into ${OUTPUT_DIR}/"
    cp -R "$GRADLE_RESULTS_DIR/." "$OUTPUT_DIR/"
else
    warn "No JUnit report directory found at ${GRADLE_RESULTS_DIR}."
fi

# Also keep the human-readable HTML report when Gradle produced one.
if [[ -d "$GRADLE_HTML_REPORT_DIR" ]]; then
    log "Collecting HTML report into ${OUTPUT_DIR}/html/"
    mkdir -p "$OUTPUT_DIR/html"
    cp -R "$GRADLE_HTML_REPORT_DIR/." "$OUTPUT_DIR/html/"
fi

# ------------------------------------------------------------------
# 5. Report final status with the proper exit code
# ------------------------------------------------------------------
if [[ $TEST_EXIT_CODE -eq 0 ]]; then
    log "Tests passed. Reports available in ${OUTPUT_DIR}/"
else
    err "Tests failed (exit code ${TEST_EXIT_CODE}). See reports in ${OUTPUT_DIR}/"
fi

exit $TEST_EXIT_CODE
