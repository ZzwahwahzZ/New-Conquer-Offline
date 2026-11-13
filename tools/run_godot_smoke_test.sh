#!/usr/bin/env bash
set -Eeuo pipefail

test_script="${1:?Usage: run_godot_smoke_test.sh scripts/test.gd [timeout] [headless|display]}"
test_timeout="${2:-150s}"
test_mode="${3:-headless}"
test_name="$(basename "${test_script%.gd}")"
log_dir="reports/smoke-tests"
log_file="${log_dir}/${test_name}.log"
mkdir -p "$log_dir"

echo "SMOKE_TEST_START: ${test_script}"
set +e
test_command=(godot --headless --path . -s "$test_script")
if [[ "$test_mode" == "display" ]]; then
  command -v xvfb-run >/dev/null || { echo "::error::xvfb-run is required for display-mode smoke tests."; exit 127; }
  test_command=(xvfb-run -a godot --path . -s "$test_script")
elif [[ "$test_mode" != "headless" ]]; then
  echo "::error::Unknown smoke-test mode: ${test_mode}"
  exit 2
fi
timeout --signal=TERM --kill-after=10s "$test_timeout" \
  "${test_command[@]}" 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

if [[ "$status" -ne 0 ]]; then
  echo "::error::Smoke test ${test_script} failed or exceeded its ${test_timeout} timeout (exit ${status})."
  echo "----- Last 30 log lines: ${test_script} -----"
  tail -n 30 "$log_file" || true
  exit "$status"
fi

echo "SMOKE_TEST_PASS: ${test_script}"
