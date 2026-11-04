"""Cinematic finish on top of the per-photo clean-up: a filmic tone curve
(rich but not crushed blacks, soft highlight roll-off), cool shadows and
warm highlights kept away from skin, slightly restrained colour, a little
halation round the brightest lights, a soft vignette and fine grain."""
import sys
import cv2
import numpy as np

def curve_lut(points):
    xs, ys = zip(*points)
    x = np.linspace(0, 1, 256)
    return np.interp(x, xs, ys).astype(np.float32)

TONE = curve_lut([(0, 0.03), (0.12, 0.065), (0.3, 0.215), (0.5, 0.455), (0.7, 0.70), (0.88, 0.87), (1, 0.95)])

def grade(img, strength=1.0):
    f = img.astype(np.float32) / 255
    # Skin mask (orange hues, moderate saturation): kept out of the cool shift.
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    h, s, v = hsv[..., 0] * 2, hsv[..., 1] / 255, hsv[..., 2] / 255
    skin = ((h > 5) & (h < 45) & (s > 0.15) & (s < 0.7) & (v > 0.25)).astype(np.float32)
    skin = cv2.GaussianBlur(skin, (0, 0), 6)

    # Filmic curve on luminance, colour carried along.
    lum = f @ np.array([0.0722, 0.7152, 0.2126], np.float32)  # BGR
    toned = np.interp(lum, np.linspace(0, 1, 256), TONE)
    ratio = (toned + 1e-4) / (lum + 1e-4)
    f = f * ratio[..., None]

    # Split tone: teal shadows, warm highlights (BGR).
    teal = np.array([0.62, 0.52, 0.30], np.float32)
    warm = np.array([0.70, 0.86, 1.00], np.float32)
    lum = np.clip(f @ np.array([0.0722, 0.7152, 0.2126], np.float32), 0, 1)
    ws = (np.clip(1 - lum / 0.5, 0, 1) ** 1.3 * 0.24 * (1 - 0.8 * skin))[..., None]
    wh = (np.clip((lum - 0.55) / 0.45, 0, 1) ** 1.2 * 0.10)[..., None]
    f = f * (1 - ws) + (lum[..., None] * teal * 1.4) * ws
    f = f * (1 - wh) + (f * warm) * wh * 0 + (lum[..., None] * warm) * wh

    # Restrained colour, skin left as is.
    lum = f @ np.array([0.0722, 0.7152, 0.2126], np.float32)
    sat = (0.76 + 0.24 * skin)[..., None]
    f = lum[..., None] + (f - lum[..., None]) * sat

    # Halation: a warm glow bleeding from the brightest spots.
    bright = np.clip((lum - 0.82) / 0.18, 0, 1)
    glow = cv2.GaussianBlur(bright, (0, 0), f.shape[0] * 0.012)
    f = f + glow[..., None] * np.array([0.10, 0.22, 0.45], np.float32) * 0.35

    # Soft vignette.
    hgt, wid = lum.shape
    yy, xx = np.mgrid[0:hgt, 0:wid].astype(np.float32)
    r = np.sqrt(((xx - wid / 2) / (wid / 2)) ** 2 + ((yy - hgt / 2) / (hgt / 2)) ** 2) / np.sqrt(2)
    f = f * (1 - (np.clip((r - 0.5) / 0.5, 0, 1) ** 1.6 * 0.38))[..., None]

    # Fine luminance grain.
    rng = np.random.default_rng(7)
    g = cv2.GaussianBlur(rng.normal(0, 1, (hgt, wid)).astype(np.float32), (0, 0), 0.7)
    f = f + g[..., None] * 0.012

    out = img.astype(np.float32) / 255 * (1 - strength) + f * strength
    return np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8)

if __name__ == "__main__":
    for src, dst in zip(sys.argv[1::2], sys.argv[2::2]):
        cv2.imwrite(dst, grade(cv2.imread(src)), [cv2.IMWRITE_JPEG_QUALITY, 90, cv2.IMWRITE_JPEG_PROGRESSIVE, 1, cv2.IMWRITE_JPEG_OPTIMIZE, 1])
        print(dst)
