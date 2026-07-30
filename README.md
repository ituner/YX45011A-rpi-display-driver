# YX45011A Raspberry Pi display driver

This repository prepares a Raspberry Pi 5 to run the YX45011A adapter-board
display as a small, always-on MIPI-DSI status screen. It is intentionally
conservative: the supplied schematic identifies the electrical connector and
the panel controller, but it does **not** contain the panel's manufacturer
initialisation commands or timings. Those commands are required to safely bind
an ST7701S panel in Linux. Do not use a random ST7701S overlay.

## What you need

* A Raspberry Pi 5 running a current, standard 64-bit Raspberry Pi OS image.
* The YX45011A adapter board and display assembly.
* A 22-way, 0.5 mm-pitch, top-contact FFC cable suitable for the board and
  Raspberry Pi 5 orientation.
* A **panel-specific, known-good `.dtbo` overlay** from the display supplier or
  a validated board bring-up. The installation is complete without it, but the
  MIPI panel will not be driven until it is supplied.

## Physical connection

Use either Raspberry Pi 5 combined **MIPI CSI/DSI 22-pin connector** (`CAM/DISP
0` or `CAM/DISP 1`). The Pi 5 ports are mini 22-pin, 0.5 mm pitch, 11.5 mm wide;
they are not the older 15-pin DSI connector. The supplied adapter schematic
labels its input as `CN2`, a **0.5 mm 22p FPC, top contact**, and carries two
data lanes plus clock and DSI control lines. Its drawn host is a Luckfox board,
not a Raspberry Pi 5, so the schematic alone does not prove that every
22-way cable preserves the required pin mapping.

1. Shut down and unplug the Pi.
2. Open the selected Pi 5 `CAM/DISP` latch and the adapter's CN2 latch.
3. Insert the FFC with the contact side and cable direction required by both
   latches; close both latches without force.
4. Power the Pi using an appropriate USB-C supply, then boot it.

The two Pi 5 ports are dual-use CSI/DSI ports. A display must be configured as
DSI in its panel overlay; a cable that merely fits is not proof of pinout or
orientation compatibility.

## Quick install

Clone this repository on the Pi, then run:

```sh
sudo ./scripts/install.sh
```

The installer checks that it is running on a Raspberry Pi 5, installs the
runtime packages, installs the status-screen program and service, and creates
`/etc/yx45011a-display.conf`. It is idempotent. It does not enable the service
or alter boot firmware until configuration is explicitly requested.

## Configure and enable

First obtain a panel overlay specifically verified for this display, its
wiring, and the Pi MIPI port it targets. Then install it:

```sh
sudo ./scripts/configure.sh --panel-overlay /path/to/verified-panel.dtbo --enable
sudo reboot
```

The supplied overlay itself selects `CAM/DISP 0` or `CAM/DISP 1`; this tool
does not rewrite its DSI graph. `configure.sh` copies that overlay into the Pi
boot overlay directory, adds a marked `dtoverlay=` entry, and enables
`yx45011a-display.service`. It refuses a non-DTBO file and leaves the boot
configuration alone until those checks pass. The boot configuration change and
reboot are deliberately explicit because an invalid overlay can prevent the
panel from appearing.

After boot, inspect the service:

```sh
systemctl status yx45011a-display.service
journalctl -u yx45011a-display.service -b --no-pager
```

To change only the displayed text or logical framebuffer parameters, edit
`/etc/yx45011a-display.conf` and restart the service:

```sh
sudo systemctl restart yx45011a-display.service
```

## Framebuffer: 400x960

The service creates and draws into a **400x960 logical software framebuffer**
(`FRAMEBUFFER_WIDTH=400`, `FRAMEBUFFER_HEIGHT=960`) before rotating and scaling
it to the active DRM output. This is deliberately **400x960, not 320x960**.

This setting is verified by the installed program: it constructs
`pygame.Surface((400, 960))` from the configuration and logs the logical and
active output sizes at startup. It does **not** change the kernel's MIPI/DRM
panel mode. The schematic identifies a 960x320 panel, but contains no verified
timing or initialisation sequence, so the panel overlay remains the authority
for native DRM mode. The program letterboxes the rotated framebuffer if the
active output's aspect ratio differs.

## Troubleshooting

* **No `/dev/dri/card*` or no panel connector:** confirm the supplier overlay,
  selected port, cable orientation, and reboot. Check `dmesg | grep -iE
  'dsi|drm|st7701'`.
* **Service repeatedly restarts:** read the journal command above. On a desktop
  image, stop other software that has exclusively claimed the same DRM output.
* **Blank or corrupt panel:** do not substitute a generic ST7701S sequence.
  Obtain the exact panel timing and initialisation data from the display
  supplier. Raspberry Pi's DSI driver guidance notes that these data are often
  critical.
* **Wrong orientation:** set `ROTATION=90`, `180`, or `270` in the configuration
  file, then restart the service. The default is `90` for a portrait 400x960
  logical framebuffer.

## Uninstall

```sh
sudo yx45011a-uninstall
```

Running `sudo ./scripts/uninstall.sh` from a cloned checkout is equivalent.

The uninstaller stops and disables the service, removes its installed program,
configuration, unit file, copied overlay, and only the marked `dtoverlay=`
block created by this project. It never deletes other boot configuration. If a
panel overlay was configured, reboot after uninstalling.

## Schematic notes

The original reference is preserved at
[`hardware/SCH_Schematic2_2026-04-21.pdf`](hardware/SCH_Schematic2_2026-04-21.pdf).
Its SHA-256 is:

```text
5d8ab0a5f3fdba6bf4f8dc7c40b4baca196a74cd3175ebae25cf249c2f17a548
```

3.3V LDO not needed; ignore it.

## Sources used for the connector and software boundary

* Raspberry Pi documents the Pi 5's two combined 22-pin, 0.5 mm MIPI CSI/DSI
  ports: <https://www.raspberrypi.com/documentation/computers/raspberry-pi.html>
* Raspberry Pi's DSI-driver guide explains that panel timing and manufacturer
  initialisation data can be critical: <https://pip-assets.raspberrypi.com/categories/1259-audio-camera-and-display/documents/RP-003472-WP/Using-a-DSI-display.pdf>
* Linux's ST7701 binding defines panel-specific compatible strings and required
  supplies/reset wiring: <https://www.kernel.org/doc/Documentation/devicetree/bindings/display/panel/sitronix%2Cst7701.yaml>
