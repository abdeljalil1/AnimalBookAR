#!/usr/bin/env python3
"""Draws the app icon (an open book with the horse standing on it, on the
brand orange) and writes the Android launcher icons, the adaptive icon layers,
the splash picture and the iOS app icons.

    python3 tool/make_icon.py      (after tool/make_stickers.py)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
STICKER = ROOT / "app" / "assets" / "thumbs" / "horse_sticker.png"
N = 1024


def gradient(size, top, bottom):
    g = Image.new("RGB", (1, 2))
    g.putpixel((0, 0), top)
    g.putpixel((0, 1), bottom)
    return g.resize((size, size), Image.BICUBIC)


def foreground(size=N):
    """The book and the horse on a transparent layer (centred in the safe zone)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = size / 1024
    # shadow under the book
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([300 * s, 690 * s, 724 * s, 760 * s], fill=(0, 0, 0, 70))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14 * s)))
    # the open book: two pages and a spine
    for x0, x1, tilt in [(250, 512, 1), (512, 774, -1)]:
        d.polygon([(x0 * s, (600 - 30 * tilt) * s if x0 == 250 else 600 * s), (x1 * s, 600 * s if x0 == 250 else (600 - 30 * -tilt) * s),
                   (x1 * s, 720 * s if x0 == 250 else 700 * s), (x0 * s, 700 * s if x0 == 250 else 720 * s)], fill=(255, 255, 255, 255))
    d.polygon([(250 * s, 570 * s), (512 * s, 600 * s), (512 * s, 720 * s), (250 * s, 690 * s)], fill=(255, 255, 255, 255))
    d.polygon([(774 * s, 570 * s), (512 * s, 600 * s), (512 * s, 720 * s), (774 * s, 690 * s)], fill=(250, 241, 226, 255))
    for i in range(3):  # lines of text
        y = 615 + i * 24
        d.line([(285 * s, (y - 8) * s), (480 * s, (y + 14) * s)], fill=(232, 112, 42, 160), width=int(8 * s))
        d.line([(545 * s, (y + 14) * s), (740 * s, (y - 8) * s)], fill=(47, 111, 208, 140), width=int(8 * s))
    d.line([(512 * s, 600 * s), (512 * s, 720 * s)], fill=(214, 196, 168, 255), width=int(6 * s))
    # the horse, standing on the book
    with Image.open(STICKER) as horse:
        horse = horse.convert("RGBA").resize((int(430 * s), int(430 * s)), Image.LANCZOS)
        im.alpha_composite(horse, (int(300 * s), int(215 * s)))
    # sparkles
    for cx, cy, r in [(250, 300, 26), (780, 260, 34), (720, 470, 18)]:
        d.polygon([(cx * s, (cy - r) * s), ((cx + r * 0.3) * s, (cy - r * 0.3) * s), ((cx + r) * s, cy * s),
                   ((cx + r * 0.3) * s, (cy + r * 0.3) * s), (cx * s, (cy + r) * s), ((cx - r * 0.3) * s, (cy + r * 0.3) * s),
                   ((cx - r) * s, cy * s), ((cx - r * 0.3) * s, (cy - r * 0.3) * s)], fill=(255, 225, 120, 255))
    return im


def main():
    bg = gradient(N, (243, 154, 76), (196, 86, 26)).convert("RGBA")
    fg = foreground()
    full = bg.copy()
    full.alpha_composite(fg)
    # legacy square icons, with rounded corners like most launchers draw them
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, N - 1, N - 1], radius=230, fill=255)
    rounded = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    rounded.paste(full, (0, 0), mask)
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dens, px in sizes.items():
        d = RES / f"mipmap-{dens}"
        d.mkdir(exist_ok=True)
        rounded.resize((px, px), Image.LANCZOS).save(d / "ic_launcher.png")
        # adaptive icon layers are 108 dp with a 72 dp safe zone: shrink the art into it
        a = int(px * 108 / 48)
        layer = Image.new("RGBA", (a, a), (0, 0, 0, 0))
        art = fg.resize((int(a * 0.78), int(a * 0.78)), Image.LANCZOS)
        layer.alpha_composite(art, ((a - art.width) // 2, (a - art.height) // 2))
        layer.save(d / "ic_launcher_foreground.png")
        bg.resize((a, a)).save(d / "ic_launcher_background.png")
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n')
    # splash: the art in the middle of the brand colour
    for dens, px in sizes.items():
        fg.resize((px * 4, px * 4), Image.LANCZOS).save(RES / f"mipmap-{dens}" / "launch_image.png")
    # iOS: every icon in the asset catalogue, square and opaque (iOS rounds the corners itself)
    ios = ROOT / "app" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    opaque = full.convert("RGB")
    for f in ios.glob("*.png"):
        with Image.open(f) as old:
            size = old.size
        opaque.resize(size, Image.LANCZOS).save(f)
    (ROOT / "tool" / "test-output").mkdir(exist_ok=True)
    full.resize((512, 512), Image.LANCZOS).save(ROOT / "tool" / "test-output" / "icon.png")
    print("wrote launcher icons, adaptive layers and splash image")


if __name__ == "__main__":
    main()
