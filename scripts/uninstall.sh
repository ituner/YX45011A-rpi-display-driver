#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID} -eq 0 ]] || { echo "Run with sudo: sudo ./scripts/uninstall.sh" >&2; exit 1; }
systemctl disable --now yx45011a-display.service >/dev/null 2>&1 || true
krel=$(uname -r)
boot_dir=/boot/firmware
[[ -d ${boot_dir} ]] || boot_dir=/boot
config_txt=${boot_dir}/config.txt
module_dst=/lib/modules/${krel}/kernel/drivers/gpu/drm/panel/panel-sitronix-st7701.ko
backup=/var/lib/yx45011a-display/panel-sitronix-st7701.${krel}.ko.original
if [[ -f ${backup} && -f ${module_dst} ]]; then
  install -m 0644 "${backup}" "${module_dst}"
  depmod -a "${krel}"
fi
if [[ -f ${config_txt} ]]; then
  tmp_file=$(mktemp); trap 'rm -f "${tmp_file}"' EXIT
  awk '/^# BEGIN YX45011A DISPLAY$/ {skip=1; next} /^# END YX45011A DISPLAY$/ {skip=0; next} !skip {print}' "${config_txt}" >"${tmp_file}"
  install -m 0644 "${tmp_file}" "${config_txt}"
fi
rm -f "${boot_dir}/overlays/yousee-yx45011act2.dtbo" /etc/systemd/system/yx45011a-display.service /etc/yx45011a-display.conf /usr/local/sbin/yx45011a-configure /usr/local/sbin/yx45011a-uninstall
rm -rf /usr/local/lib/yx45011a-display /usr/local/src/yx45011a-display
systemctl daemon-reload
echo "YX45011A support removed and the original running-kernel ST7701 module restored when available. Reboot required."
