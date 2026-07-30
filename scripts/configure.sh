#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi

if (($#)); then
  echo "No panel overlay is required: this package installs the known-good YX45011ACT2 overlay itself." >&2
  exit 2
fi

systemctl enable yx45011a-display.service
echo "YX45011A is configured for CAM/DISP 1. Reboot required."
