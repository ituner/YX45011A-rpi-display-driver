#!/usr/bin/env bash
# Run the installed YX45011A display application in verification mode.
set -Eeuo pipefail

[[ ${EUID} -eq 0 ]] || {
  echo "Run with sudo: sudo yx45011a-display-test [seconds]" >&2
  exit 1
}

duration=${1:-15}
[[ ${duration} =~ ^[1-9][0-9]*$ ]] || {
  echo "Duration must be a positive whole number of seconds." >&2
  exit 1
}

display_app=/usr/local/lib/yx45011a-display/display_app.py
[[ -x ${display_app} ]] || {
  echo "Display application is not installed. Run the YX45011A installer first." >&2
  exit 1
}

was_active=0
if systemctl is-active --quiet yx45011a-display.service; then
  was_active=1
fi

restore_service() {
  if [[ ${was_active} -eq 1 ]]; then
    systemctl start yx45011a-display.service ||
      echo "Could not restore yx45011a-display.service; start it manually." >&2
  fi
}
trap restore_service EXIT

systemctl stop yx45011a-display.service
echo "Showing YX45011A test pattern for ${duration} seconds (Ctrl+C exits early)."
set +e
DISPLAY_MODE=verification timeout --foreground --signal=INT "${duration}s" "${display_app}"
status=$?
set -e

# GNU timeout returns 124 after its expected timeout; that is a successful test run.
if [[ ${status} -ne 0 && ${status} -ne 124 ]]; then
  exit "${status}"
fi
