#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: sudo ./scripts/configure.sh --panel-overlay FILE.dtbo [--enable]

Installs a supplier-validated panel overlay and registers it in config.txt.
This changes boot configuration and requires a reboot.
EOF
}

overlay_source=
enable=0
while (($#)); do
  case "$1" in
    --panel-overlay) overlay_source=${2:-}; shift 2 ;;
    --enable) enable=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo." >&2
  exit 1
fi
if [[ ! -f ${overlay_source} || ${overlay_source##*.} != dtbo ]]; then
  echo "--panel-overlay must name an existing .dtbo file." >&2
  exit 2
fi
if ! dtc -I dtb -O dts "${overlay_source}" >/dev/null 2>&1; then
  echo "The supplied file is not a readable device-tree overlay." >&2
  exit 2
fi

boot_dir=/boot/firmware
[[ -d ${boot_dir} ]] || boot_dir=/boot
config_txt=${boot_dir}/config.txt
overlays_dir=${boot_dir}/overlays
if [[ ! -d ${overlays_dir} || ! -f ${config_txt} ]]; then
  echo "Could not find Raspberry Pi boot config/overlays directory." >&2
  exit 1
fi

install -m 0644 "${overlay_source}" "${overlays_dir}/yx45011a-panel.dtbo"
tmp_file=$(mktemp)
trap 'rm -f "${tmp_file}"' EXIT
awk '/^# BEGIN YX45011A DISPLAY$/ {skip=1; next} /^# END YX45011A DISPLAY$/ {skip=0; next} !skip {print}' "${config_txt}" >"${tmp_file}"
{
  cat "${tmp_file}"
  printf '\n# BEGIN YX45011A DISPLAY\n'
  printf '# The supplied panel overlay selects the CAM/DISP port.\n'
  printf 'dtoverlay=yx45011a-panel\n'
  printf '# END YX45011A DISPLAY\n'
} >"${config_txt}"

if (( enable )); then
  systemctl enable yx45011a-display.service
fi
echo "Overlay installed. Reboot required."
