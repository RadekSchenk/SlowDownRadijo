"""Per-photo clean-up for the show artwork: white balance, exposure and
contrast per photo (not a shared look), 2x super-resolution (EDSR),
gentle sharpening, saved as 1600 px JPEGs. cinematic.py then adds the
finish. For a new show photo:

    pip install opencv-contrib-python-headless numpy
    curl -LO https://raw.githubusercontent.com/Saafke/EDSR_Tensorflow/master/models/EDSR_x2.pb
    python3 enhance.py EDSR_x2.pb photo.jpg clean.jpg     # ~4-7 min on a laptop CPU
    python3 cinematic.py clean.jpg ShowArtNewShow.jpg
"""
import sys, time
import cv2
import numpy as np

SR_MODEL = sys.argv[1]
OUT_SIZE = 1600

sr = cv2.dnn_superres.DnnSuperResImpl_create()
sr.readModel(SR_MODEL)
sr.setModel("edsr", 2)

def white_balance(img, strength=0.6):
    # Grey-world on the brighter, less saturated pixels only (walls, shirts,
    # skies), so a purple backdrop or a green lawn isn't "corrected" away.
    f = img.astype(np.float32)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    mask = (hsv[..., 1] < 60) & (hsv[..., 2] > 60) & (hsv[..., 2] < 245)
    if mask.sum() < 0.03 * mask.size:
        return img
    means = f[mask].mean(0)
    gains = means.mean() / np.maximum(means, 1)
    gains = 1 + (gains - 1) * strength
    gains = np.clip(gains, 0.85, 1.18)
    return np.clip(f * gains, 0, 255).astype(np.uint8)

def tone(img):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    # Levels: black and white points from the luminance, gently.
    lo, hi = np.percentile(l, [0.4, 99.6])
    lf = np.clip((l.astype(np.float32) - lo) / max(hi - lo, 1) * 255, 0, 255)
    l = (l.astype(np.float32) * 0.35 + lf * 0.65)
    # Local contrast for depth, blended in lightly.
    clahe = cv2.createCLAHE(clipLimit=1.6, tileGridSize=(8, 8))
    lc = clahe.apply(np.clip(l, 0, 255).astype(np.uint8)).astype(np.float32)
    l = l * 0.6 + lc * 0.4
    # Lift the shadows a touch on dark photos.
    mean = l.mean() / 255
    if mean < 0.38:
        gamma = 0.85 if mean < 0.3 else 0.92
        l = 255 * (l / 255) ** gamma
    lab = cv2.merge([np.clip(l, 0, 255).astype(np.uint8), a, b])
    return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

def vibrance(img, amount=0.22):
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV).astype(np.float32)
    s = hsv[..., 1] / 255
    s = s + amount * s * (1 - s) * 1.6   # muted colours more than strong ones
    hsv[..., 1] = np.clip(s, 0, 1) * 255
    return cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)

def denoise_if_dark(img):
    l = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).mean()
    if l < 70:
        return cv2.fastNlMeansDenoisingColored(img, None, 4, 4, 7, 21)
    return img

def sharpen(img, radius=1.2, amount=0.45, threshold=3):
    blur = cv2.GaussianBlur(img, (0, 0), radius)
    diff = img.astype(np.int16) - blur.astype(np.int16)
    mask = np.abs(diff).max(-1, keepdims=True) > threshold
    out = img.astype(np.float32) + amount * diff * mask
    return np.clip(out, 0, 255).astype(np.uint8)

def enhance(src, dst):
    t = time.time()
    img = cv2.imread(src)
    img = denoise_if_dark(img)
    img = white_balance(img)
    img = tone(img)
    img = vibrance(img)
    up = sr.upsample(img)
    up = cv2.resize(up, (OUT_SIZE, OUT_SIZE), interpolation=cv2.INTER_AREA if up.shape[0] > OUT_SIZE else cv2.INTER_LANCZOS4)
    up = sharpen(up)
    cv2.imwrite(dst, up, [cv2.IMWRITE_JPEG_QUALITY, 90, cv2.IMWRITE_JPEG_PROGRESSIVE, 1, cv2.IMWRITE_JPEG_OPTIMIZE, 1])
    print(f"{dst}: {img.shape[1]} -> {OUT_SIZE} px in {time.time() - t:.0f} s", flush=True)

for src, dst in zip(sys.argv[2::2], sys.argv[3::2]):
    enhance(src, dst)
