#!/usr/bin/env python3
"""YX45011A KMSDRM status screen and visual verification pattern."""
import os
import signal
import sys
import time

import pygame


def setting(name, default):
    value = os.environ.get(name, default)
    try:
        return int(value)
    except ValueError:
        raise SystemExit(f"{name} must be an integer, got {value!r}")


WIDTH = setting("FRAMEBUFFER_WIDTH", "400")
HEIGHT = setting("FRAMEBUFFER_HEIGHT", "960")
ACTIVE_WIDTH = setting("ACTIVE_WIDTH", "960")
ACTIVE_HEIGHT = setting("ACTIVE_HEIGHT", "400")
ROTATION = setting("ROTATION", "90") % 360
TITLE = os.environ.get("TITLE", "YX45011A display service")
DISPLAY_MODE = os.environ.get("DISPLAY_MODE", "status")
RUNNING = True


def stop(_signum, _frame):
    global RUNNING
    RUNNING = False


def draw_status(logical, font):
    logical.fill((12, 18, 30))
    lines = (
        TITLE,
        "Logical framebuffer",
        f"{WIDTH} x {HEIGHT}",
        time.strftime("%Y-%m-%d %H:%M:%S"),
    )
    y = ACTIVE_HEIGHT // 6
    for line in lines:
        text = font.render(line, True, (225, 238, 255))
        logical.blit(text, ((ACTIVE_WIDTH - text.get_width()) // 2, y))
        y += text.get_height() + ACTIVE_HEIGHT // 24


def draw_verification(logical, font):
    colors = (
        (235, 51, 35),
        (245, 196, 40),
        (57, 181, 74),
        (39, 129, 211),
        (111, 62, 160),
        (240, 240, 240),
    )
    bar_width = ACTIVE_WIDTH // len(colors)
    for index, color in enumerate(colors):
        pygame.draw.rect(logical, color, (index * bar_width, 0, bar_width, 320))
    pygame.draw.rect(logical, (255, 255, 255), (4, 4, ACTIVE_WIDTH - 8, 312), 4)
    pygame.draw.rect(logical, (0, 0, 0), (0, 272, ACTIVE_WIDTH, 44))
    label = font.render(
        "YX45011A  |  960 x 320 visible  |  400 x 960 DRM", True, (255, 255, 255)
    )
    logical.blit(label, ((ACTIVE_WIDTH - label.get_width()) // 2, 278))
    pygame.draw.rect(logical, (0, 0, 0), (0, 320, ACTIVE_WIDTH, ACTIVE_HEIGHT - 320))


def main():
    if WIDTH <= 0 or HEIGHT <= 0:
        raise SystemExit("Framebuffer dimensions must be positive.")
    if ROTATION not in (0, 90, 180, 270):
        raise SystemExit("ROTATION must be 0, 90, 180, or 270.")
    if DISPLAY_MODE not in ("status", "verification"):
        raise SystemExit("DISPLAY_MODE must be status or verification.")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    drm_device = os.environ.get("DRM_DEVICE", "auto")
    if drm_device == "auto":
        if not os.path.isdir("/dev/dri"):
            raise SystemExit("No DRM directory found at /dev/dri.")
        cards = sorted(
            os.path.join("/dev/dri", entry)
            for entry in os.listdir("/dev/dri")
            if entry.startswith("card")
        )
        if not cards:
            raise SystemExit("No DRM card found under /dev/dri.")
        drm_device = cards[0]
    if not os.path.exists(drm_device):
        raise SystemExit(f"DRM_DEVICE does not exist: {drm_device}")
    os.environ["SDL_DRM_DEVICE"] = drm_device
    pygame.init()
    output = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    logical = pygame.Surface((ACTIVE_WIDTH, ACTIVE_HEIGHT))
    status_font = pygame.font.Font(None, max(24, ACTIVE_HEIGHT // 7))
    verification_font = pygame.font.Font(None, 32)
    print(
        f"YX45011A framebuffer: {WIDTH}x{HEIGHT}; active scan: {ACTIVE_WIDTH}x{ACTIVE_HEIGHT}; "
        f"active DRM output: {output.get_width()}x{output.get_height()}; "
        f"device: {drm_device}; rotation: {ROTATION}",
        flush=True,
    )
    while RUNNING:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return
        if DISPLAY_MODE == "verification":
            draw_verification(logical, verification_font)
        else:
            draw_status(logical, status_font)
        frame = pygame.transform.rotate(logical, -ROTATION)
        if frame.get_size() != output.get_size():
            raise SystemExit(f"DRM output is {output.get_size()}, expected {frame.get_size()}")
        output.blit(frame, (0, 0))
        pygame.display.flip()
        time.sleep(0.1)
    pygame.quit()


if __name__ == "__main__":
    try:
        main()
    except pygame.error as exc:
        print(f"pygame/KMSDRM failed: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(1)
