#!/usr/bin/env python3
"""The Google Play listing's graphics, from the iOS app's assets.

    python3 tools/android/store_graphics.py

Writes android/store/icon-512.png (the app icon, 512 x 512) and
android/store/feature-graphic.png (1024 x 500: the logo over the home
screen's dark sky with its red and purple clouds, and the genres).
The phone screenshots come from StoreScreenshotTest (about 1078 x 1918);
this brings them to exactly 1080 x 1920, the 9:16 that Play requires.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "SlowDownRadijo/Resources/Assets.xcassets"
FONT = ROOT / "SlowDownRadijo/Resources/Fonts/Manrope-ExtraBold.ttf"
OUT = ROOT / "android/store"

BACKGROUND = (0x12, 0x0E, 0x25)
LIVE_RED = (0xDB, 0x30, 0x4E)
PURPLE = (0x43, 0x37, 0x85)
MUTED = (0xB8, 0xAF, 0xDC)


def icon() -> None:
    Image.open(ASSETS / "AppIcon.appiconset/icon-1024.png").convert("RGB").resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png")


def glow(size, centre, radius, colour, strength):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    x, y = centre
    ImageDraw.Draw(layer).ellipse((x - radius, y - radius, x + radius, y + radius), fill=colour + (strength,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def feature_graphic() -> None:
    size = (1024, 500)
    image = Image.new("RGBA", size, BACKGROUND + (255,))
    image.alpha_composite(glow(size, (180, 40), 260, LIVE_RED, 150))
    image.alpha_composite(glow(size, (880, 120), 300, PURPLE, 170))
    image.alpha_composite(glow(size, (520, 520), 220, LIVE_RED, 60))

    logo = Image.open(ASSETS / "BrandLogo.imageset/BrandLogo.png").convert("RGBA")
    height = 300
    logo = logo.resize((round(logo.width * height / logo.height), height), Image.LANCZOS)
    image.alpha_composite(logo, ((size[0] - logo.width) // 2, 50))

    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT), 34)
    text = "HIP HOP · SOUL · JAZZ · FUNK"
    width = draw.textlength(text, font=font)
    draw.text(((size[0] - width) / 2, 395), text, font=font, fill=MUTED)

    image.convert("RGB").save(OUT / "feature-graphic.png")


def screenshots() -> None:
    for path in sorted(OUT.glob("screenshots/*/*.png")):
        shot = Image.open(path).convert("RGB")
        if shot.size != (1080, 1920):
            shot.resize((1080, 1920), Image.LANCZOS).save(path)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    icon()
    feature_graphic()
    screenshots()
    print("written:", *(p.relative_to(ROOT) for p in sorted(OUT.glob("*.png"))))
