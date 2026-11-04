"""Turns the raw simulator recording into the showcase video.

Run by .github/workflows/showcase.yml after ShowcaseTests has driven the
app: keeps only the stretches the test marked with SHOWCASE_CLIP lines (the
gestures and the pauses after them, not XCUITest's waiting), puts the phone
screen on a 1080 x 1920 card in the app's colours with a caption for each
scene, adds an intro and an outro with the logo, and lays the live stream's
sound (recorded at the same time, uncut) underneath.

    python3 compose.py <work dir>

The work dir holds raw.mov, rec_start (unix time the recording started),
test.log, and optionally radio.aac with audio_start.
"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

WORK = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "SlowDownRadijo/Resources/Fonts")
LOGO = os.path.join(ROOT, "SlowDownRadijo/Resources/Assets.xcassets/BrandLogo.imageset/BrandLogo.png")

W, H, FPS = 1080, 1920, 30
BG = (0x12, 0x0E, 0x25)
MUTED = (0xB8, 0xAF, 0xDC)
WHITE = (255, 255, 255)
PHONE_H = 1440
PHONE_Y = 400
INTRO, OUTRO, XFADE = 3.2, 3.6, 0.6

# Scene → caption.
CAPTIONS = {
    "home": ("Živé vysílání", "Pořad, moderátor a skladba, která právě hraje"),
    "songs": ("Co hrálo před chvílí", "Swipni zpátky až o 10 skladeb, každou najdeš na Spotify"),
    "timer": ("Časovač vypnutí", "Usni u rádia, appka ho pak sama vypne"),
    "scroll": ("Tvoje statistiky", "Kolik času s rádiem trávíš"),
    "program": ("Program na celý týden", "S upozorněním na oblíbené pořady"),
    "stats": ("Statistiky a žebříček", "Jak si stojíš mezi ostatními posluchači"),
    "message": ("Vzkaz do studia", "Nahraj hlasový vzkaz pro moderátory"),
    "support": ("Podpoř rádio", "Přímo z appky"),
    "menu": ("Česky i anglicky", "Novinky, upozornění a nastavení v menu"),
}


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"Manrope-{weight}.ttf"), size)


def wrap(draw, text, fnt, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if draw.textlength(candidate, font=fnt) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def centred_text(draw, y, text, fnt, fill, width=940, gap=10):
    for line in wrap(draw, text, fnt, width):
        box = draw.textbbox((0, 0), line, font=fnt)
        draw.text(((W - (box[2] - box[0])) / 2 - box[0], y), line, font=fnt, fill=fill)
        y += (box[3] - box[1]) + gap + fnt.size * 0.25
    return y


def caption_png(name, title, subtitle):
    img = Image.new("RGBA", (W, PHONE_Y), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    y = centred_text(draw, 120, title, font("ExtraBold", 68), WHITE)
    centred_text(draw, y + 6, subtitle, font("SemiBold", 36), MUTED)
    path = os.path.join(WORK, f"cap-{name}.png")
    img.save(path)
    return path


def card_png(name, subtitle):
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    logo = Image.open(LOGO).convert("RGBA")
    logo_w = 420
    logo = logo.resize((logo_w, round(logo.height * logo_w / logo.width)), Image.LANCZOS)
    top = 620
    img.paste(logo, ((W - logo_w) // 2, top), logo)
    y = top + logo.height + 80
    y = centred_text(draw, y, "Slow Down Rádijo", font("ExtraBold", 76), WHITE)
    centred_text(draw, y + 10, subtitle, font("SemiBold", 40), MUTED)
    path = os.path.join(WORK, f"{name}.png")
    img.save(path)
    return path


def phone_layers(width, height):
    radius = round(width * 0.135)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius, fill=255)
    mask_path = os.path.join(WORK, "mask.png")
    mask.save(mask_path)
    # A faint outline, so the dark screen reads as a phone on the dark card.
    pad = 6
    frame = Image.new("RGBA", (width + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (0, 0, width + 2 * pad - 1, height + 2 * pad - 1), radius + pad, outline=(255, 255, 255, 46), width=3
    )
    frame_path = os.path.join(WORK, "frame.png")
    frame.save(frame_path)
    return mask_path, frame_path, pad


def main():
    clips = []
    for line in open(os.path.join(WORK, "test.log"), errors="ignore"):
        if "SHOWCASE_CLIP" in line:
            parts = line.split("SHOWCASE_CLIP", 1)[1].split()
            if len(parts) >= 3:
                clips.append((parts[0], float(parts[1]), float(parts[2])))
    clips.sort(key=lambda c: c[1])
    # Overlapping or touching stretches become one.
    merged = []
    for scene, start, end in clips:
        if merged and start <= merged[-1][2] + 0.05:
            merged[-1][2] = max(merged[-1][2], end)
        else:
            merged.append([scene, start, end])
    print("clips:", [(c[0], round(c[2] - c[1], 1)) for c in merged])
    rec_start = float(open(os.path.join(WORK, "rec_start")).read())
    seg_start = merged[0][1]
    duration = sum(end - start for _, start, end in merged)

    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
        "-of", "json", os.path.join(WORK, "raw.mov")]))
    raw_w, raw_h = probe["streams"][0]["width"], probe["streams"][0]["height"]
    raw_duration = float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
        os.path.join(WORK, "raw.mov")]).strip() or 0)
    stop_path = os.path.join(WORK, "rec_stop")
    if os.path.exists(stop_path):
        wall = float(open(stop_path).read()) - rec_start
        print(f"recording: {raw_duration:.1f} s of video for {wall:.1f} s of wall time")
    phone_w = round(PHONE_H * raw_w / raw_h / 2) * 2
    mask, frame, pad = phone_layers(phone_w, PHONE_H)
    phone_x = (W - phone_w) // 2

    # Caption windows on the cut timeline: one per run of a scene.
    windows, t = [], 0.0
    for scene, start, end in merged:
        length = end - start
        if windows and windows[-1][0] == scene:
            windows[-1][2] = t + length
        elif scene in CAPTIONS:
            windows.append([scene, t, t + length])
        t += length

    bg = os.path.join(WORK, "bg.png")
    Image.new("RGB", (W, H), BG).save(bg)
    intro = card_png("intro", "Teď hraje Morning Coffee")
    outro = card_png("outro", "slowdownradijo.cz")

    inputs = ["-i", os.path.join(WORK, "raw.mov"),
              "-loop", "1", "-t", f"{duration:.3f}", "-i", bg,
              "-loop", "1", "-i", mask,
              "-loop", "1", "-t", f"{duration:.3f}", "-i", frame,
              "-loop", "1", "-t", f"{INTRO:.3f}", "-framerate", str(FPS), "-i", intro,
              "-loop", "1", "-t", f"{OUTRO:.3f}", "-framerate", str(FPS), "-i", outro]
    cuts = [f"[0:v]split={len(merged)}" + "".join(f"[r{i}]" for i in range(len(merged)))]
    for i, (_, start, end) in enumerate(merged):
        cuts.append(f"[r{i}]trim=start={start - rec_start:.3f}:end={end - rec_start:.3f},setpts=PTS-STARTPTS,fps={FPS}[s{i}]")
    cuts.append("".join(f"[s{i}]" for i in range(len(merged))) + f"concat=n={len(merged)}:v=1:a=0[cut]")
    filters = cuts + [
        f"[cut]scale={phone_w}:{PHONE_H}:flags=lanczos,format=rgba[ph]",
        "[2:v]format=gray[mask]",
        "[ph][mask]alphamerge[phr]",
        f"[1:v]fps={FPS},format=rgba[bg]",
        f"[bg][phr]overlay=x={phone_x}:y={PHONE_Y}:shortest=1[v0]",
        f"[v0][3:v]overlay=x={phone_x - pad}:y={PHONE_Y - pad}:shortest=1[v1]",
    ]
    label, index = "v1", 6
    for i, (name, start, end) in enumerate(windows):
        title, subtitle = CAPTIONS[name]
        inputs += ["-loop", "1", "-t", f"{duration:.3f}", "-i", caption_png(name, title, subtitle)]
        fade_out = max(start + 0.4, end - 0.35)
        filters.append(
            f"[{index}:v]fps={FPS},format=rgba,fade=t=in:st={start:.3f}:d=0.35:alpha=1,"
            f"fade=t=out:st={fade_out:.3f}:d=0.35:alpha=1[c{i}]"
        )
        filters.append(f"[{label}][c{i}]overlay=0:0:shortest=1[w{i}]")
        label, index = f"w{i}", index + 1
    filters.append(f"[{label}]format=yuv420p,setsar=1[main]")
    filters.append(f"[4:v]fps={FPS},format=yuv420p,setsar=1[intro]")
    filters.append(f"[5:v]fps={FPS},format=yuv420p,setsar=1[outro]")
    filters.append(f"[intro][main]xfade=transition=fade:duration={XFADE}:offset={INTRO - XFADE:.3f}[im]")
    total = INTRO + duration + OUTRO - 2 * XFADE
    filters.append(
        f"[im][outro]xfade=transition=fade:duration={XFADE}:offset={INTRO + duration - 2 * XFADE:.3f}[v]"
    )

    audio_args = []
    radio = os.path.join(WORK, "radio.aac")
    if os.path.exists(radio) and os.path.getsize(radio) > 50_000:
        audio_start = float(open(os.path.join(WORK, "audio_start")).read())
        # Final time t shows the moment seg_start - (INTRO - XFADE) + t.
        offset = seg_start - (INTRO - XFADE) - audio_start
        inputs += ["-i", radio]
        if offset >= 0:
            a = f"[{index}:a]atrim=start={offset:.3f},asetpts=PTS-STARTPTS"
        else:
            delay = round(-offset * 1000)
            a = f"[{index}:a]adelay={delay}|{delay}"
        filters.append(
            f"{a},atrim=duration={total:.3f},afade=t=in:d=1.5,"
            f"afade=t=out:st={total - 2.5:.3f}:d=2.5,volume=0.9[a]"
        )
        audio_args = ["-map", "[a]", "-c:a", "aac", "-b:a", "192k"]
    else:
        print("no radio audio recorded")

    out = os.path.join(WORK, "showcase.mp4")
    cmd = ["ffmpeg", "-y", "-loglevel", "warning", *inputs,
           "-filter_complex", ";".join(filters), "-map", "[v]", *audio_args,
           "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
           "-r", str(FPS), "-t", f"{total:.3f}", "-movflags", "+faststart", out]
    print(" ".join(cmd))
    subprocess.check_call(cmd)
    print(f"showcase.mp4: {total:.1f} s, {os.path.getsize(out) / 1e6:.1f} MB")


main()
