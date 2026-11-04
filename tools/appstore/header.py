#!/usr/bin/env python3
"""The App Store product page header (5244 x 2950): the logo and the claim
on the left, three phones with the app on the right, over the same sunset
panorama as the screenshots (tools/appstore/frame.py).

    python3 tools/appstore/header.py <screens dir> <output dir>

<screens dir> holds the plain screens from AppStoreScreenshotTests
("cs 1 home.png" or "cs_1_home.jpg", ...); one header is made per language.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frame import FONT, LAVENDER, NIGHT, ROOT, SUN_ORANGE, SUN_RED, SUN_YELLOW, LIVE_RED, VIOLET, rounded  # noqa: E402

W, H = 5244, 2950
LOGO = os.path.join(ROOT, "SlowDownRadijo/Resources/Assets.xcassets/BrandLogo.imageset/BrandLogo.png")
CLAIM = "No music.\nNo life."

# Left to right behind the phones: programme, home (front), message.
PHONES = [("3 programme", 2950, 0.9), ("5 message", 4350, 0.9), ("1 home", 3650, 1.0)]
MAIN_SCREEN_H = 2250


def background():
    stops = [SUN_YELLOW, SUN_ORANGE, SUN_RED, LIVE_RED, VIOLET, (60, 40, 140)]
    strip = Image.new("RGB", (len(stops), 1))
    for i, c in enumerate(stops):
        strip.putpixel((i, 0), c)
    colour = strip.resize((W, 1), Image.BILINEAR).resize((W, H))
    card = Image.new("RGB", (W, H), NIGHT)
    # Colour at the top, night blue towards the bottom.
    mask = Image.linear_gradient("L").resize((W, H)).point(lambda v: int(max(0, 255 - v * 1.15) * 0.9))
    card.paste(colour, (0, 0), mask)
    return card.convert("RGBA")


def phone(screen, screen_h):
    scale = screen_h / screen.height
    sw, sh = round(screen.width * scale), screen_h
    bezel, radius = round(26 * screen_h / 2086), round(118 * screen_h / 2086)
    pw, ph = sw + 2 * bezel, sh + 2 * bezel
    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, pw - 1, ph - 1), radius + bezel, fill=(12, 10, 22, 255))
    d.rounded_rectangle((0, 0, pw - 1, ph - 1), radius + bezel, outline=(*LAVENDER, 90), width=4)
    body.paste(screen.resize((sw, sh), Image.LANCZOS), (bezel, bezel), rounded((sw, sh), radius))
    return body


def header(screens, out_path):
    card = background()
    draw = ImageDraw.Draw(card)

    logo = Image.open(LOGO).convert("RGBA")
    lh = 780
    logo = logo.resize((round(logo.width * lh / logo.height), lh), Image.LANCZOS)
    card.alpha_composite(logo, (430, 620))

    font = ImageFont.truetype(FONT, 330)
    draw.multiline_text((430, 1560), CLAIM, font=font, fill=(255, 255, 255), spacing=40)

    for key, cx, s in PHONES:
        body = phone(screens[key], round(MAIN_SCREEN_H * s))
        x, y = cx - body.width // 2, (H - body.height) // 2 + (90 if s < 1 else 0)
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((x, y + 40, x + body.width, y + 40 + body.height), 160,
                                                 fill=(0, 0, 0, 150))
        card = Image.alpha_composite(card, shadow.filter(ImageFilter.GaussianBlur(70)))
        card.alpha_composite(body, (x, y))

    card.convert("RGB").save(out_path)


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    by_lang = {}
    for path in glob.glob(os.path.join(src, "*")):
        name = os.path.splitext(os.path.basename(path))[0].replace("_", " ")
        lang, key = name.split(" ", 1)
        by_lang.setdefault(lang, {})[key] = Image.open(path).convert("RGB")
    for lang, screens in sorted(by_lang.items()):
        if all(k in screens for k, _, _ in PHONES):
            target = os.path.join(out, f"{lang} header.png")
            header(screens, target)
            print(target)


if __name__ == "__main__":
    main()
