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
krel=$(uname -r)
boot_dir=/boot/firmware
[[ -d ${boot_dir} ]] || boot_dir=/boot
config_txt=${boot_dir}/config.txt
overlays_dir=${boot_dir}/overlays
module_dst=/lib/modules/${krel}/kernel/drivers/gpu/drm/panel/panel-sitronix-st7701.ko
state_dir=/var/lib/yx45011a-display

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential raspberrypi-kernel-headers device-tree-compiler python3-pygame

[[ -f ${module_dst} && -d ${overlays_dir} && -f ${config_txt} ]] || { echo "Required Pi kernel/boot paths are missing." >&2; exit 1; }
install -d -m 0755 /usr/local/src/yx45011a-display /usr/local/lib/yx45011a-display "${state_dir}"
install -m 0644 "${repo_dir}/driver/panel-sitronix-st7701.c" /usr/local/src/yx45011a-display/
install -m 0644 "${repo_dir}/driver/Makefile" /usr/local/src/yx45011a-display/
install -m 0644 "${repo_dir}/overlays/yousee-yx45011act2-pi5-overlay.dts" /usr/local/src/yx45011a-display/
make -C "/lib/modules/${krel}/build" M=/usr/local/src/yx45011a-display modules
[[ -f ${state_dir}/panel-sitronix-st7701.${krel}.ko.original ]] || install -m 0644 "${module_dst}" "${state_dir}/panel-sitronix-st7701.${krel}.ko.original"
install -m 0644 /usr/local/src/yx45011a-display/panel-sitronix-st7701.ko "${module_dst}"
dtc -@ -I dts -O dtb -o "${overlays_dir}/yousee-yx45011act2.dtbo" /usr/local/src/yx45011a-display/yousee-yx45011act2-pi5-overlay.dts
depmod -a "${krel}"

tmp_file=$(mktemp)
trap 'rm -f "${tmp_file}"' EXIT
awk '/^# BEGIN YX45011A DISPLAY$/ {skip=1; next} /^# END YX45011A DISPLAY$/ {skip=0; next} !skip {print}' "${config_txt}" >"${tmp_file}"
{
  cat "${tmp_file}"
  printf '\n# BEGIN YX45011A DISPLAY\n'
  printf 'dtparam=i2c_csi_dsi=on\n'
  printf 'dtoverlay=vc4-kms-v3d\n'
  printf 'dtoverlay=yousee-yx45011act2\n'
  printf 'disable_fw_kms_setup=1\n'
  printf '# END YX45011A DISPLAY\n'
} >"${config_txt}"

install -m 0755 "${repo_dir}/src/display_app.py" /usr/local/lib/yx45011a-display/display_app.py
# Remove the standalone test program installed by older revisions; verification
# now runs through display_app.py.
rm -f /usr/local/lib/yx45011a-display/test_pattern.py
install -m 0755 "${repo_dir}/scripts/display-test.sh" /usr/local/bin/yx45011a-display-test
install -m 0755 "${repo_dir}/scripts/configure.sh" /usr/local/sbin/yx45011a-configure
install -m 0755 "${repo_dir}/scripts/uninstall.sh" /usr/local/sbin/yx45011a-uninstall
[[ -e /etc/yx45011a-display.conf ]] || install -m 0644 "${repo_dir}/systemd/yx45011a-display.conf" /etc/yx45011a-display.conf
install -m 0644 "${repo_dir}/systemd/yx45011a-display.service" /etc/systemd/system/yx45011a-display.service
systemctl daemon-reload
systemctl enable yx45011a-display.service
echo "Installed the known-good 400x960 YX45011ACT2 driver for CAM/DISP 0. Reboot required."
