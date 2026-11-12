#!/usr/bin/env bash
set -Eeuo pipefail

test_script="${1:?Usage: run_godot_smoke_test.sh scripts/test.gd}"
test_name="$(basename "${test_script%.gd}")"
log_dir="reports/smoke-tests"
log_file="${log_dir}/${test_name}.log"
mkdir -p "$log_dir"

echo "SMOKE_TEST_START: ${test_script}"
set +e
timeout --signal=TERM --kill-after=10s 90s \
  godot --headless --audio-driver Dummy --rendering-method dummy --rendering-driver dummy \
  --path . --script "$test_script" 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo "::error::Smoke test ${test_script} failed or exceeded its 90-second timeout (exit ${status})."
  echo "----- Last 30 log lines: ${test_script} -----"
  tail -n 30 "$log_file" || true
  exit "$status"
fi

echo "SMOKE_TEST_PASS: ${test_script}"
