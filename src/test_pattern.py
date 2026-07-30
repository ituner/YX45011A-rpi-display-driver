#!/usr/bin/env python3
"""Show a known-good YX45011A 960x400/400x960 KMS test pattern."""
import os
import signal
import time

import pygame

RUNNING = True


def stop(_signum, _frame):
    global RUNNING
    RUNNING = False


def main():
    os.environ.setdefault("SDL_VIDEODRIVER", "kmsdrm")
    os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    os.environ.setdefault("SDL_DRM_DEVICE", "/dev/dri/card0")
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    pygame.init()
    output = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)
    active = pygame.Surface((960, 400))
    colors = ((235, 51, 35), (245, 196, 40), (57, 181, 74), (39, 129, 211), (111, 62, 160), (240, 240, 240))
    bar_width = 960 // len(colors)
    for index, color in enumerate(colors):
        pygame.draw.rect(active, color, (index * bar_width, 0, bar_width, 320))
    pygame.draw.rect(active, (255, 255, 255), (4, 4, 952, 312), 4)
    pygame.draw.rect(active, (0, 0, 0), (0, 320, 960, 80))
    pygame.draw.rect(active, (0, 0, 0), (0, 272, 960, 44))
    font = pygame.font.Font(None, 32)
    label = font.render("YX45011A  |  960 x 320 visible  |  400 x 960 DRM", True, (255, 255, 255))
    active.blit(label, ((960 - label.get_width()) // 2, 278))
    frame = pygame.transform.rotate(active, -90)
    if frame.get_size() != output.get_size():
        raise SystemExit(f"DRM output is {output.get_size()}, expected {frame.get_size()}")
    while RUNNING:
        output.blit(frame, (0, 0))
        pygame.display.flip()
        time.sleep(0.05)
    pygame.quit()


if __name__ == "__main__":
    main()
