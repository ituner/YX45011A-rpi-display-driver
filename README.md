# YX45011A Raspberry Pi display driver

This repository installs the known-good Raspberry Pi 5 configuration for the
YX45011A/YX45011ACT2 bar display: the 60 Hz ST7701 driver, its exact panel
initialisation sequence, and the Pi 5 CAM/DISP 0 Device Tree overlay.

## What you need

* A Raspberry Pi 5 running a current, standard 64-bit Raspberry Pi OS image.
* The YX45011A adapter board and display assembly.
* A 22-way, 0.5 mm-pitch, top-contact FFC cable suitable for the board and
  Raspberry Pi 5 orientation.
* Internet access while the installer installs Raspberry Pi kernel headers and
  build tools.

## Physical connection

Use Raspberry Pi 5 combined **MIPI CSI/DSI 22-pin connector CAM/DISP 0**. The Pi 5 ports are mini 22-pin, 0.5 mm pitch, 11.5 mm wide;
they are not the older 15-pin DSI connector. The supplied adapter schematic
labels its input as `CN2`, a **0.5 mm 22p FPC, top contact**, and carries two
data lanes plus clock and DSI control lines. It is the working adapter-board
reference for this project.

1. Shut down and unplug the Pi.
2. Open **only the Pi 5 `CAM/DISP 0` (DSI0) latch** and the adapter's CN2 latch. Do not use `CAM/DISP 1` with this configuration.
3. Insert the FFC with the contact side and cable direction required by both
   latches; close both latches without force.
4. Power the Pi using an appropriate USB-C supply, then boot it.

The installed overlay targets the RP1 DSI0 host, which is CAM/DISP 0. Do not
move the display to CAM/DISP 1 without a matching overlay.

## Quick install

Clone this repository on the Pi, then run:

```sh
sudo ./scripts/install.sh
```

The installer checks for Pi 5, installs kernel headers/build tools, builds the
bundled known-good `panel-sitronix-st7701` module for the running kernel,
backs up the stock module, compiles/installs the bundled overlay, configures
boot firmware, and enables the display service. Reboot when it completes.

## Configure and enable

The complete LCD configuration is installed by `install.sh`; no supplier
overlay is needed. This command only enables the boot service again if it was
disabled:

```sh
sudo ./scripts/configure.sh
```

The installed overlay selects CAM/DISP 0 and binds `yousee,yx45011act2` to the
bundled driver. It uses two DSI lanes and the verified 400x960 DRM mode.

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

The kernel driver creates a **400x960 DRM framebuffer**
(`FRAMEBUFFER_WIDTH=400`, `FRAMEBUFFER_HEIGHT=960`) before rotating and scaling
it to the active DRM output. This is deliberately **400x960, not 320x960**.

The bundled driver creates the 400x960 DRM mode. The physical active scan is
960x400, rotated into that framebuffer; the upper 960x320 rows are visible and
the final 80 rows are hidden on this glass. The service draws a 960x400 active
image, rotates it into the exact 400x960 DRM framebuffer, and rejects an
unexpected output size instead of scaling or letterboxing.

## Troubleshooting

* **No `/dev/dri/card*` or no panel connector:** confirm CAM/DISP 0, cable
  orientation, and reboot. Check `dmesg | grep -iE 'dsi|drm|st7701|yx45011'`.
* **Service repeatedly restarts:** read the journal command above. On a desktop
  image, stop other software that has exclusively claimed the same DRM output.
* **Blank or corrupt panel after a kernel update:** rerun `sudo ./scripts/install.sh`
  to rebuild the bundled module for the new kernel, then reboot.
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
* The exact tested source, overlay, and bring-up record are included under
  [`driver/`](driver/), [`overlays/`](overlays/), and
  [`docs/known-good-bringup.md`](docs/known-good-bringup.md).
