# YX45011A / YX45011ACT2 LCD on Raspberry Pi 5

This note records the working LCD configuration found during bring-up on
2026-07-28, so a fresh Raspberry Pi 5 can be rebuilt without rediscovering
the geometry, timing, and framebuffer assumptions.

## Hardware

- Raspberry Pi 5
- Bar-type LCD sold/documented as `YX45011A` / `YX45011ACT2`
- MIPI DSI panel, not SPI
- ST7701-family controller
- 2-lane MIPI DSI
- Physical visible glass is landscape `960x320`

The manufacturer file calls the panel `320x960`, but the working model is a
rotated framebuffer driving a landscape panel:

- DRM framebuffer: `400x960`
- Physical active scan model: `960x400`
- Physical visible area: `960x320`
- Hidden/inactive lower area: `80` physical rows, `Y=320..399`
- Practical UI safe area: about `x=4..955`, `y=0..319`

Keep UI content inside `960x320`, with a few pixels of horizontal inset for
important borders or text.

## Final Working Driver Variant

Use this source tree:

```text
tools/st7701-variants/h400_60hz_c1_0f10_webgip/
```

The key source file is:

```text
tools/st7701-variants/h400_60hz_c1_0f10_webgip/panel-sitronix-st7701.c
```

The previous very-good baseline was:

```text
tools/st7701-variants/h400_29m_c1_0f10_webgip/
```

The 60 Hz variant was preferred because it slightly reduced subtle regional
waterfall shimmer and is a better fit for the SDR UI.

## Current Live Timing

Expected `dmesg` lines for the final 60 Hz variant:

```text
rp1dsi_host_attach: Attach DSI device name=yx45011act2 channel=0 lanes=2 format=0 flags=0xc03
rp1dsi: Nominal Byte clock 48611111 DPI clock 32407407
YX45011ACT2 source-built h400_60hz_c1_0f10_webgip init start
YX45011ACT2 source-built h400_60hz_c1_0f10_webgip init end
```

Derived rates:

- Pixel/DPI clock: about `32.407 MHz`
- Refresh: about `60 Hz`
- DSI byte clock: about `48.611 MHz`
- Per-lane MIPI high-speed rate: about `389 Mbps/lane`
- Total raw over two lanes: about `778 Mbps`

DRM mode in the driver:

```c
.clock        = 32412,
.hdisplay     = 400,
.hsync_start  = 400 + 50,
.hsync_end    = 400 + 50 + 10,
.htotal       = 400 + 50 + 10 + 84,
.vdisplay     = 960,
.vsync_start  = 960 + 16,
.vsync_end    = 960 + 16 + 2,
.vtotal       = 960 + 16 + 2 + 15,
```

The framebuffer should report:

```sh
cat /sys/class/graphics/fb0/virtual_size
# 400,960
cat /sys/class/graphics/fb0/bits_per_pixel
# 32
cat /sys/class/graphics/fb0/stride
# 1600
```

## Important Init Changes

The manufacturer sequence contained a formatting typo:

```text
Generic_Write(0xB1,,0x40,...)
```

The double comma is only a typo in the text file. The actual working driver
uses the intended bytes after `0xB1`.

The important successful changes were not the comma. They were:

- Use `960x400` physical active scan instead of `960x320`.
- Present it to Linux as a rotated `400x960` DRM mode.
- Keep only the top `960x320` physical rows visible/useful.
- Use the web-derived GIP tail for this ST7701 bar-panel family.
- Tune `C1` porch to `0x0F, 0x10`.
- Use a 60 Hz clock point after the image was otherwise correct.

Key init bytes in the winning variant:

```c
ST7701_WRITE(st7701, 0xC0, 0x77, 0x00);
ST7701_WRITE(st7701, 0xC1, 0x0F, 0x10);
ST7701_WRITE(st7701, 0xC2, 0x01, 0x02);
ST7701_WRITE(st7701, 0xC3, 0x02);
ST7701_WRITE(st7701, 0xCC, 0x10);
```

Final GIP tail uses:

```c
ST7701_WRITE(st7701, 0xE5,
	     0x05, 0xCD, 0x82, 0x82,
	     0x01, 0xC9, 0x82, 0x82,
	     0x07, 0xCF, 0x82, 0x82,
	     0x03, 0xCB, 0x82, 0x82);

ST7701_WRITE(st7701, 0xE8,
	     0x06, 0xCE, 0x82, 0x82,
	     0x02, 0xCA, 0x82, 0x82,
	     0x08, 0xD0, 0x82, 0x82,
	     0x04, 0xCC, 0x82, 0x82);
```

Pixel format:

```c
ST7701_WRITE(st7701, 0x3A, 0x77);
```

MIPI DSI attach settings:

```c
dsi->mode_flags = MIPI_DSI_MODE_VIDEO |
		  MIPI_DSI_MODE_VIDEO_BURST |
		  MIPI_DSI_MODE_LPM |
		  MIPI_DSI_CLOCK_NON_CONTINUOUS;
dsi->format = MIPI_DSI_FMT_RGB888;
dsi->lanes = 2;
```

## Pi 5 Device Tree Overlay

Use:

```text
tools/yousee-yx45011act2-pi5-overlay.dts
```

It enables RP1 DSI and creates this panel node:

```dts
panel@0 {
	compatible = "yousee,yx45011act2";
	reg = <0>;
	reset-gpios = <&rp1_gpio 46 0>;
};
```

The reset GPIO polarity is intentional for the adapter used here. The module
pin is RESET# on the adapter, and this setting leaves the physical reset line
high before DSI init commands are sent.

## Fresh Raspberry Pi 5 Build Steps

Install dependencies on the Pi:

```sh
sudo apt update
sudo apt install -y build-essential raspberrypi-kernel-headers device-tree-compiler python3-pil
```

Copy the final driver source and overlay to the Pi:

```sh
mkdir -p ~/st7701-variants/h400_60hz_c1_0f10_webgip
```

From the development machine:

```sh
scp tools/st7701-variants/h400_60hz_c1_0f10_webgip/panel-sitronix-st7701.c \
    tools/st7701-variants/h400_60hz_c1_0f10_webgip/Makefile \
    pi@raspberrypi.local:~/st7701-variants/h400_60hz_c1_0f10_webgip/

scp tools/yousee-yx45011act2-pi5-overlay.dts \
    pi@raspberrypi.local:~/
```

Build the out-of-tree panel module on the Pi:

```sh
cd ~/st7701-variants/h400_60hz_c1_0f10_webgip
make -C /lib/modules/$(uname -r)/build M=$PWD modules
```

Install it over the stock ST7701 panel module:

```sh
krel="$(uname -r)"
src="$PWD/panel-sitronix-st7701.ko"
dst="/lib/modules/$krel/kernel/drivers/gpu/drm/panel/panel-sitronix-st7701.ko"

sudo cp "$dst" "$dst.bak-before-yx45011a-$(date +%Y%m%d-%H%M%S)"
sudo install -m 644 "$src" "$dst"
sudo depmod -a "$krel"
```

If the `tools/st7701-variants` helper tree is copied to
`/home/ituner/st7701-variants`, the same install can be done with:

```sh
sudo /home/ituner/st7701-variants/install_st7701_variant.sh h400_60hz_c1_0f10_webgip
```

Build and install the overlay:

```sh
dtc -@ -I dts -O dtb -o yousee-yx45011act2.dtbo ~/yousee-yx45011act2-pi5-overlay.dts
sudo install -m 755 yousee-yx45011act2.dtbo /boot/firmware/overlays/
```

Edit `/boot/firmware/config.txt` and make sure these are present:

```ini
dtparam=i2c_csi_dsi=on
dtoverlay=vc4-kms-v3d
dtoverlay=yousee-yx45011act2
disable_fw_kms_setup=1
```

The current test system also has:

```ini
max_framebuffers=2
dtoverlay=gt911-camdisp1
```

The GT911 overlay is for touch and is not required just to light the LCD.

## GT911 Touch Controller

The working touch controller overlay is:

```text
tools/gt911-camdisp1-overlay.dts
```

On the current `p5` system it is installed as:

```text
/boot/firmware/overlays/gt911-camdisp1.dtbo
```

The controller is a Goodix GT911 on CAM/DISP1 I2C:

- I2C bus: `/dev/i2c-11`
- I2C address: `0x5d`
- Interrupt GPIO: RP1 GPIO `48`
- Raw touch geometry: `320x960`
- Linux input geometry after axis swap: `960x320`

Expected `dmesg` lines:

```text
Goodix-TS 11-005d: ID 911, version: 1060
input: 11-005d Goodix Capacitive TouchScreen
```

Expected input device:

```sh
evtest /dev/input/event5
# ABS_X / ABS_MT_POSITION_X max 959
# ABS_Y / ABS_MT_POSITION_Y max 319
```

Important: the panel responds at `0x5d`, not `0x14`. A node at `0x14`
loads but fails probe with `I2C communication failure: -121`.

Reboot:

```sh
sudo reboot
```

Verify after reboot:

```sh
dmesg | grep -E 'Byte clock|DPI clock|YX45011|rp1dsi_host_attach|lanes='
cat /sys/class/graphics/fb0/virtual_size
cat /sys/class/graphics/fb0/bits_per_pixel
cat /sys/class/graphics/fb0/stride
```

Expected:

```text
400,960
32
1600
```

## Framebuffer Rendering Rules

The Linux framebuffer is `400x960`, but the human-facing image should be
prepared as landscape `960x320`.

To show a `960x320` visible image:

1. Create a `960x400` active image.
2. Paste the `960x320` visible content at `(0, 0)`.
3. Fill physical rows `Y=320..399` black.
4. Rotate the active image clockwise into framebuffer orientation using
   `active.rotate(-90, expand=True)`, producing `400x960`.
5. Write BGRA little-endian pixels to `/dev/fb0`.

The helper used during bring-up is:

```text
tools/write_png_to_fb.py
```

Example:

```sh
sudo ./write_png_to_fb.py /tmp/image-framebuffer-cw.png
```

For UI layout, use:

```text
visible canvas: 960x320
recommended safe content: x=4..955, y=0..319
```

Do not render important UI into physical rows `Y=320..399`; they are in the
active scan but not visible on this glass.

## Known Good Test Images

Useful tools from this repo:

```text
tools/lcd_horizontal_visible320_probe.py
tools/lcd_bar_bottom_fine_calibration.py
tools/lcd_bar_xedge_fine_calibration.py
tools/lcd_bar_edge_ladder_wide.py
tools/make_yx45011_fb_image.py
tools/write_png_to_fb.py
```

The SDR waterfall test used at the end showed the final image quality well.
Subtle regional shimmer was slightly improved by moving from the 29.2 MHz
pixel clock variant to the 60 Hz variant.

## Custom Boot Logo

There are three different "boot logo" layers on Raspberry Pi OS:

- Firmware/EEPROM display before Linux owns DRM.
- Kernel console logo and kernel messages.
- User-space splash after `/dev/fb0` exists.

For this custom panel, the practical approach is:

1. Hide the stock kernel logo.
2. Keep or hide boot text depending on whether debugging is needed.
3. Draw a custom `400x960` framebuffer image as soon as the panel is ready.

This does not replace the very earliest firmware stage, but it is much easier
and safer than rebuilding the kernel just to replace the compiled-in logo.

Convert a normal landscape image to the panel framebuffer format:

```sh
python3 tools/make_yx45011_fb_image.py my-logo.png /tmp/boot-logo-fb.png --fit contain --background '#000000'
```

Copy the converter result and framebuffer writer to the Pi:

```sh
sudo mkdir -p /usr/local/share/yx45011
sudo install -m 644 /tmp/boot-logo-fb.png /usr/local/share/yx45011/boot-logo-fb.png
sudo install -m 755 tools/write_png_to_fb.py /usr/local/bin/write_png_to_fb.py
```

Add this to `/boot/firmware/cmdline.txt`, keeping it all on one line:

```text
logo.nologo vt.global_cursor_default=0
```

Optional: add `quiet` if boot messages should be mostly hidden. Leave `quiet`
out while debugging the panel driver, because boot messages are useful.

Create `/etc/systemd/system/yx45011-boot-logo.service`:

```ini
[Unit]
Description=Show YX45011 boot logo
DefaultDependencies=no
After=systemd-udev-settle.service
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'test -e /dev/fb0 && /usr/local/bin/write_png_to_fb.py /usr/local/share/yx45011/boot-logo-fb.png'

[Install]
WantedBy=sysinit.target
```

Enable it:

```sh
sudo systemctl daemon-reload
sudo systemctl enable yx45011-boot-logo.service
sudo reboot
```

If a full animated, polished splash is needed later, use Plymouth. For the
current SDR appliance, a direct framebuffer logo service is simpler and avoids
orientation surprises.

## Kernel Update Warning

The panel module is installed under:

```text
/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-sitronix-st7701.ko
```

A Raspberry Pi kernel update can replace this module or boot into a new
`uname -r` directory. After a kernel update, rebuild and reinstall the module
for the new kernel version.

## Rollback

The install command above saves a backup next to the original module, named
similar to:

```text
panel-sitronix-st7701.ko.bak-before-yx45011a-YYYYMMDD-HHMMSS
```

To roll back:

```sh
krel="$(uname -r)"
dst="/lib/modules/$krel/kernel/drivers/gpu/drm/panel/panel-sitronix-st7701.ko"
sudo cp "$dst.bak-before-yx45011a-YYYYMMDD-HHMMSS" "$dst"
sudo depmod -a "$krel"
sudo reboot
```

Also remove or comment this line in `/boot/firmware/config.txt` if the custom
overlay should not bind:

```ini
dtoverlay=yousee-yx45011act2
```
