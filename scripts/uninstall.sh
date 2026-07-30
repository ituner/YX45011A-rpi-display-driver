#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo: sudo ./scripts/uninstall.sh" >&2
  exit 1
fi

systemctl disable --now yx45011a-display.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/yx45011a-display.service
rm -f /etc/yx45011a-display.conf
rm -f /usr/local/sbin/yx45011a-configure
rm -f /usr/local/sbin/yx45011a-uninstall
rm -rf /usr/local/lib/yx45011a-display

boot_dir=/boot/firmware
[[ -d ${boot_dir} ]] || boot_dir=/boot
config_txt=${boot_dir}/config.txt
if [[ -f ${config_txt} ]]; then
  tmp_file=$(mktemp)
  trap 'rm -f "${tmp_file}"' EXIT
  awk '/^# BEGIN YX45011A DISPLAY$/ {skip=1; next} /^# END YX45011A DISPLAY$/ {skip=0; next} !skip {print}' "${config_txt}" >"${tmp_file}"
  install -m 0644 "${tmp_file}" "${config_txt}"
fi
rm -f "${boot_dir}/overlays/yx45011a-panel.dtbo"
systemctl daemon-reload
echo "YX45011A display support removed. Reboot if a panel overlay was configured."
