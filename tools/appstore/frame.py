#!/usr/bin/env python3
"""App Store screenshots with a caption, in the station's colours.

Takes the plain screens from AppStoreScreenshotTests ("cs 1 home.png", ...)
and puts each on a 1320 x 2868 card: a benefit in Manrope ExtraBold at the
top, the screen in a phone outline below it, over a glow in the logo's
sunset colours fading into the app's night blue. The glows move from card
to card, so the five read as one strip in the App Store.

    python3 tools/appstore/frame.py <screens dir> <output dir>

Needs Pillow. Run by the appstore-screenshots job in
.github/workflows/ui-tests.yml.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "SlowDownRadijo/Resources/Fonts/Manrope-ExtraBold.ttf")

NIGHT = (18, 14, 37)        # Theme.background #120E25
LIVE_RED = (219, 48, 78)    # Theme.liveRed
SUN_YELLOW = (250, 184, 23)
SUN_ORANGE = (232, 101, 43)
SUN_RED = (224, 74, 79)
VIOLET = (107, 79, 191)
LAVENDER = (184, 175, 220)  # Theme.mutedText

# Per screen: the caption in each language and the glow behind it
# (colour, centre x as a fraction of the width).
SCREENS = {
    "1 home": {
        "cs": "Hudba vybraná lidmi,\nne algoritmy",
        "en": "Music picked by people,\nnot algorithms",
        "glow": [(SUN_ORANGE, 0.15), (SUN_RED, 0.85)],
    },
    "2 sleep timer": {
        "cs": "Usínej s rádiem,\nčasovač ho vypne",
        "en": "Fall asleep to the radio,\nthe timer turns it off",
        "glow": [(SUN_RED, 0.1), (VIOLET, 0.9)],
    },
    "3 programme": {
        "cs": "Celý týden programu\ns připomínkami",
        "en": "The whole week's shows,\nwith reminders",
        "glow": [(VIOLET, 0.2), (LIVE_RED, 0.95)],
    },
    "4 stats": {
        "cs": "Tvůj čas s rádiem\nve statistikách",
        "en": "Your time with the\nstation, in numbers",
        "glow": [(LIVE_RED, 0.1), (SUN_ORANGE, 0.9)],
    },
    "5 message": {
        "cs": "Pošli vzkaz\npřímo do vysílání",
        "en": "Send a voice message\nstraight to the studio",
        "glow": [(SUN_ORANGE, 0.1), (SUN_YELLOW, 0.85)],
    },
}

PHONE_W = 960                 # the screen's width on the card
BEZEL = 26
SCREEN_RADIUS = 118
PHONE_TOP = 640


def background(glows):
    card = Image.new("RGB", (W, H), NIGHT)
    layer = Image.new("RGB", (W, H), NIGHT)
    draw = ImageDraw.Draw(layer)
    for colour, x in glows:
        cx, cy, r = int(W * x), 260, 1050
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour)
    layer = layer.filter(ImageFilter.GaussianBlur(320))
    # Strong at the top, gone by two thirds down.
    mask = Image.linear_gradient("L").resize((W, H))
    mask = mask.point(lambda v: int(max(0, 255 - v * 1.45) * 0.85))
    card.paste(layer, (0, 0), mask)
    return card


def rounded(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def frame(screen_path, lang, key, out_path):
    spec = SCREENS[key]
    card = background(spec["glow"])

    # Caption.
    draw = ImageDraw.Draw(card)
    font = ImageFont.truetype(FONT, 92)
    text = spec[lang]
    box = draw.multiline_textbbox((0, 0), text, font=font, spacing=26, align="center")
    tw, th = box[2] - box[0], box[3] - box[1]
    draw.multiline_text(((W - tw) / 2 - box[0], 330 - th / 2 - box[1]), text, font=font,
                        fill=(255, 255, 255), spacing=26, align="center")

    # The screen in a phone outline, with a soft shadow.
    screen = Image.open(screen_path).convert("RGB")
    sh = round(screen.height * PHONE_W / screen.width)
    screen = screen.resize((PHONE_W, sh), Image.LANCZOS)
    pw, ph = PHONE_W + 2 * BEZEL, sh + 2 * BEZEL
    px = (W - pw) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((px, PHONE_TOP + 30, px + pw, PHONE_TOP + 30 + ph),
                                             SCREEN_RADIUS + BEZEL, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(50))
    card = Image.alpha_composite(card.convert("RGBA"), shadow)

    body = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((0, 0, pw - 1, ph - 1), SCREEN_RADIUS + BEZEL, fill=(12, 10, 22, 255))
    # A thin light edge, like the phone's rim catching the glow.
    bd.rounded_rectangle((0, 0, pw - 1, ph - 1), SCREEN_RADIUS + BEZEL, outline=(*LAVENDER, 90), width=3)
    body.paste(screen, (BEZEL, BEZEL), rounded(screen.size, SCREEN_RADIUS))
    card.alpha_composite(body, (px, PHONE_TOP))

    card.convert("RGB").save(out_path)


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(src, "*"))):
        name = os.path.splitext(os.path.basename(path))[0].replace("_", " ")
        lang, key = name.split(" ", 1)
        if key not in SCREENS or lang not in ("cs", "en"):
            continue
        target = os.path.join(out, f"{lang} {key}.png")
        frame(path, lang, key, target)
        print(target)


if __name__ == "__main__":
    main()
