#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo ./scripts/install.sh" >&2
  exit 1
fi

if ! grep -aq "Raspberry Pi 5" /proc/device-tree/model 2>/dev/null; then
  echo "Refusing to install: this installer is intended for Raspberry Pi 5." >&2
  exit 1
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
was_enabled=0
if systemctl is-enabled --quiet yx45011a-display.service 2>/dev/null; then
  was_enabled=1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  python3-pygame device-tree-compiler

install -d -m 0755 /usr/local/lib/yx45011a-display
install -m 0755 "${repo_dir}/src/display_app.py" /usr/local/lib/yx45011a-display/display_app.py
install -m 0755 "${repo_dir}/scripts/configure.sh" /usr/local/sbin/yx45011a-configure
install -m 0755 "${repo_dir}/scripts/uninstall.sh" /usr/local/sbin/yx45011a-uninstall

if [[ ! -e /etc/yx45011a-display.conf ]]; then
  install -m 0644 "${repo_dir}/systemd/yx45011a-display.conf" /etc/yx45011a-display.conf
fi
install -m 0644 "${repo_dir}/systemd/yx45011a-display.service" /etc/systemd/system/yx45011a-display.service
systemctl daemon-reload
if (( was_enabled )); then
  systemctl try-restart yx45011a-display.service >/dev/null 2>&1 || true
else
  systemctl disable --now yx45011a-display.service >/dev/null 2>&1 || true
fi

echo "Installed. Next: sudo yx45011a-configure --panel-overlay /path/to/verified-panel.dtbo --enable"
