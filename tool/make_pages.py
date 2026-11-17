#!/usr/bin/env python3
"""Builds the printable animal book.

Reads app/assets/ar/animals.json and tool/photos/<id>.jpg, then writes:
  book/pages/<id>.png        one A4 page per animal (also the AR tracking image)
  book/animal-book.pdf       all pages, ready to print on A4
  app/assets/ar/pages/<id>.jpg  smaller copies the app shows ("Show page")
  app/assets/thumbs/<id>.jpg    round-photo thumbnails for the zoo path (square crops)

Usage: python3 tool/make_pages.py [--book=cars]   (paths for other books: see tool/bookcfg.py)
Needs Google Chrome in /Applications.
"""
import html
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

from bookcfg import BOOK

ROOT = Path(__file__).resolve().parent.parent
APP_AR = ROOT / "app" / "assets" / "ar"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Where each animal is in its photo (x, y as fractions), for the square thumbnails.
THUMB_FOCUS = {"horse": (0.38, 0.5), "fox": (0.62, 0.45), "flamingo": (0.5, 0.5),
               "parrot": (0.42, 0.45), "stork": (0.5, 0.45), "cow": (0.5, 0.5), "sheep": (0.5, 0.55),
               "zebra": (0.5, 0.5), "llama": (0.45, 0.5), "dog": (0.5, 0.45), "lion": (0.5, 0.45),
               "elephant": (0.5, 0.5), "giraffe": (0.5, 0.35), "camel": (0.5, 0.45),
               "bus": (0.45, 0.5), "firetruck": (0.45, 0.5), "truck": (0.5, 0.55)}

# A4 at 96 CSS px per inch is 794 x 1123. Screenshots use a 1.5625 scale
# factor, giving 1240 x 1754 PNGs (150 dpi).
PAGE_W, PAGE_H, SCALE = 794, 1123, 1.5625

CSS = """
@page { size: A4; margin: 0; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { background: #fff; }
.page {
  width: 794px; height: 1123px; position: relative; overflow: hidden;
  background: #fffaf0; font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif;
  border: 22px solid var(--c); page-break-after: always;
}
.page:last-child { page-break-after: auto; }
.badge {
  position: absolute; top: 26px; left: 30px; background: var(--c); color: #fff;
  font-weight: 800; font-size: 22px; padding: 8px 18px; border-radius: 30px;
}
.photo {
  position: absolute; top: 90px; left: 40px; right: 40px; height: 600px;
  border-radius: 28px; overflow: hidden; border: 6px solid var(--c);
}
.photo img { width: 100%; height: 100%; object-fit: cover; }
.names { position: absolute; top: 715px; left: 40px; right: 40px; text-align: center; }
.en { font-size: 76px; font-weight: 900; color: var(--c); line-height: 1; }
.row { display: flex; justify-content: center; gap: 36px; margin-top: 14px; align-items: baseline; }
.fr { font-size: 40px; font-weight: 700; color: #333; }
.ar { font-size: 46px; font-weight: 700; color: #333; font-family: "Geeza Pro", "Al Bayan", sans-serif; }
.facts { position: absolute; top: 905px; left: 50px; right: 50px; font-size: 21px; color: #333; line-height: 1.45; }
.facts p { margin-bottom: 4px; }
.facts .far { direction: rtl; text-align: right; font-family: "Geeza Pro", sans-serif; font-size: 23px; }
.foot {
  position: absolute; bottom: 10px; left: 30px; right: 30px; font-size: 10px; color: #777;
  display: flex; justify-content: space-between; gap: 20px;
}
"""


ICON = {"vehicles": "🚗", "letters": "✏️", "colors": "🎨"}.get(BOOK.kind, "🐾")


def page_html(a, num, credit):
    e = html.escape
    return f"""
<section class="page" style="--c:{a['color']}">
  <div class="badge">{num}</div>
  <div class="photo"><img src="{(BOOK.photos / (a['id'] + '.jpg')).as_uri()}"></div>
  <div class="names">
    <div class="en">{e(a['en'])}</div>
    <div class="row"><span class="fr">{e(a['fr'])}</span><span class="ar" dir="rtl">{e(a['ar'])}</span></div>
  </div>
  <div class="facts">
    <p>{ICON} {e(a['fact_en'])}</p>
    <p>{ICON} {e(a['fact_fr'])}</p>
    <p class="far">{e(a['fact_ar'])} {ICON}</p>
  </div>
  <div class="foot"><span>Point the Animal Book AR app at this page ({e(BOOK.cfg["en"])})</span><span>Photo: {e(credit)}</span></div>
</section>"""


LEARN_CSS = """
.letter-top { position: absolute; top: 90px; left: 40px; right: 40px; height: 430px; display: flex; gap: 26px; align-items: center; }
.big { flex: 1; height: 100%; border-radius: 28px; background: var(--c); color: #fff; display: flex;
  align-items: center; justify-content: center; font-weight: 900; line-height: 1; }
.big.ar { font-family: "Geeza Pro", "Al Bayan", sans-serif; font-size: 330px; padding-bottom: 40px; }
.big.fr { font-family: "Avenir Next", "Helvetica Neue", Arial, sans-serif; font-size: 230px; }
.pic { width: 330px; height: 330px; border-radius: 28px; overflow: hidden; border: 6px solid var(--c); flex: none; }
.pic img { width: 100%; height: 100%; object-fit: cover; }
.word { position: absolute; top: 545px; left: 40px; right: 40px; text-align: center; }
.word .main { font-size: 96px; font-weight: 900; color: var(--c); line-height: 1.05; }
.word .main.ar { font-family: "Geeza Pro", sans-serif; }
.forms { position: absolute; top: 760px; left: 60px; right: 60px; display: flex; justify-content: center; gap: 22px; }
.forms span { min-width: 120px; padding: 6px 18px; text-align: center; border: 4px dashed var(--c); border-radius: 22px;
  font-size: 74px; font-weight: 800; color: #333; font-family: "Geeza Pro", "Avenir Next", sans-serif; }
.forms-label { position: absolute; top: 722px; left: 0; right: 0; text-align: center; font-size: 20px; color: #777; }
.splash { position: absolute; top: 70px; left: 20px; right: 20px; height: 640px; }
.scene { position: absolute; top: 110px; left: 60px; right: 60px; height: 560px; }
.scene img { width: 100%; height: 100%; object-fit: contain; }
.cname { position: absolute; top: 715px; left: 40px; right: 40px; text-align: center; }
.cname .en { -webkit-text-stroke: 3px #333; }
"""

SPLASH = ("M300 40 C390 20 470 90 560 70 C680 40 760 150 720 250 C700 300 770 360 740 440 C700 560 560 560 470 600 "
          "C380 640 260 620 190 560 C110 500 30 470 40 360 C48 270 10 200 70 130 C130 60 220 60 300 40 Z")


def letter_page(a, num, credit, photo):
    e = html.escape
    lang = "ar" if BOOK.id == "letters_ar" else "fr"
    other = (f'<span class="fr">{e(a["fr"].split(" · ")[-1])}</span><span class="en" style="font-size:40px;font-weight:700;color:#333">'
             f'{e(a["en"].split(" · ")[-1])}</span>') if lang == "ar" else \
            (f'<span class="ar" dir="rtl">{e(a["ar"].split(" · ")[-1])}</span><span style="font-size:40px;font-weight:700;color:#333">'
             f'{e(a["en"].split(" · ")[-1])}</span>')
    forms = "".join(f"<span>{e(f)}</span>" for f in a["forms"])
    label = "أشكال الحرف" if lang == "ar" else "Majuscule · minuscule"
    return f"""
<section class="page" style="--c:{a['color']}">
  <div class="badge">{num}</div>
  <div class="letter-top"><div class="big {lang}" {'dir="rtl"' if lang == 'ar' else ''}>{e(a['letter'])}</div>
    <div class="pic"><img src="{photo.as_uri()}"></div></div>
  <div class="word"><div class="main {lang}" {'dir="rtl"' if lang == 'ar' else ''}>{e(a['word'])}</div>
    <div class="row">{other}</div></div>
  <div class="forms-label">{label}</div>
  <div class="forms" {'dir="rtl"' if lang == 'ar' else ''}>{forms}</div>
  <div class="facts" style="top:930px">
    <p>{ICON} {e(a['fact_en'])}</p>
    <p>{ICON} {e(a['fact_fr'])}</p>
    <p class="far">{e(a['fact_ar'])} {ICON}</p>
  </div>
  <div class="foot"><span>Point the Animal Book AR app at this page ({e(BOOK.cfg["en"])})</span><span>Photo: {e(credit)}</span></div>
</section>"""


def color_page(a, num):
    e = html.escape
    scene = BOOK.photos / (a["id"].removeprefix("color_") + ".png")
    edge = "#333" if a["color"].upper() in ("#F5F5F5", "#FDD835") else a["color"]
    return f"""
<section class="page" style="--c:{edge}">
  <div class="badge">{num}</div>
  <svg class="splash" viewBox="0 0 800 640" preserveAspectRatio="none"><path d="{SPLASH}" fill="{a['color']}" opacity=".28"
    stroke="{edge}" stroke-width="6" stroke-dasharray="18 12"/></svg>
  <div class="scene"><img src="{scene.as_uri()}"></div>
  <div class="cname">
    <div class="en" style="color:{a['color']};font-size:96px;font-weight:900;line-height:1">{e(a['en'])}</div>
    <div class="row"><span class="fr">{e(a['fr'])}</span><span class="ar" dir="rtl">{e(a['ar'])}</span></div>
  </div>
  <div class="facts">
    <p>{ICON} {e(a['fact_en'])}</p>
    <p>{ICON} {e(a['fact_fr'])}</p>
    <p class="far">{e(a['fact_ar'])} {ICON}</p>
  </div>
  <div class="foot"><span>Point the Animal Book AR app at this page ({e(BOOK.cfg["en"])})</span><span>Pictures: Animal Book AR</span></div>
</section>"""


def letter_photo(name):
    for d in ["letters", "", "cars"]:
        f = ROOT / "tool" / "photos" / d / f"{name}.jpg"
        if f.exists():
            return f
    raise SystemExit(f"no photo for {name}: put it in tool/photos/letters/{name}.jpg")


def doc(body):
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}{LEARN_CSS}</style></head><body>{body}</body></html>'


def chrome(*args):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", *args],
                   check=True, capture_output=True, timeout=120)


def make_thumb(animal_id):
    out = BOOK.thumbs / f"{animal_id}.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    fx, fy = THUMB_FOCUS.get(animal_id, (0.5, 0.5))
    with Image.open(BOOK.photos / f"{animal_id}.jpg") as im:
        im = im.convert("RGB")
        w, h = im.size
        s = min(w, h)
        left = max(0, min(w - s, int(fx * w) - s // 2))
        top = max(0, min(h - s, int(fy * h) - s // 2))
        im.crop((left, top, left + s, top + s)).resize((256, 256), Image.LANCZOS).save(out, quality=85, optimize=True)


def main():
    animals = BOOK.items
    credits = json.loads((ROOT / "tool" / "credits.json").read_text())
    BOOK.pages.mkdir(parents=True, exist_ok=True)
    BOOK.app_pages.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp())
    sections = []
    for i, a in enumerate(animals, 1):
        if BOOK.kind == "colors":
            sec = color_page(a, i)
        else:
            c = credits[a.get("photo", a["id"]) + "_photo"]
            credit = f"{c['artist']}, {c['license']}, Wikimedia Commons"
            sec = letter_page(a, i, credit, letter_photo(a["photo"])) if BOOK.kind == "letters" else page_html(a, i, credit)
        sections.append(sec)
        f = tmp / f"{a['id']}.html"
        f.write_text(doc(sec))
        out = BOOK.pages / f"{a['id']}.png"
        chrome(f"--window-size={PAGE_W},{PAGE_H}", f"--force-device-scale-factor={SCALE}",
               f"--screenshot={out}", f.as_uri())
        with Image.open(out) as im:
            im = im.convert("RGB")
            im.thumbnail((900, 900 * PAGE_H // PAGE_W + 1))
            im.save(BOOK.app_pages / f"{a['id']}.jpg", quality=85, optimize=True)
        if BOOK.kind not in ("letters", "colors"):  # those thumbnails come from make_shapes.py
            make_thumb(a["id"])
        print("page", out.relative_to(ROOT))
    book = tmp / "book.html"
    book.write_text(doc("".join(sections)))
    pdf = BOOK.pdf
    chrome(f"--print-to-pdf={pdf}", "--no-pdf-header-footer", book.as_uri())
    print("book", pdf.relative_to(ROOT))


if __name__ == "__main__":
    main()
