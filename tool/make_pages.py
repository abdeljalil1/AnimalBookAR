#!/usr/bin/env python3
"""Builds the printable animal book.

Reads app/assets/ar/animals.json and tool/photos/<id>.jpg, then writes:
  book/pages/<id>.png        one A4 page per animal (also the AR tracking image)
  book/animal-book.pdf       all pages, ready to print on A4
  app/assets/ar/pages/<id>.jpg  smaller copies the app shows on its home screen

Usage: python3 tool/make_pages.py
Needs Google Chrome in /Applications.
"""
import html
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
APP_AR = ROOT / "app" / "assets" / "ar"
BOOK = ROOT / "book"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

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


def page_html(a, num, credit):
    e = html.escape
    return f"""
<section class="page" style="--c:{a['color']}">
  <div class="badge">{num}</div>
  <div class="photo"><img src="{(ROOT / 'tool' / 'photos' / (a['id'] + '.jpg')).as_uri()}"></div>
  <div class="names">
    <div class="en">{e(a['en'])}</div>
    <div class="row"><span class="fr">{e(a['fr'])}</span><span class="ar" dir="rtl">{e(a['ar'])}</span></div>
  </div>
  <div class="facts">
    <p>🐾 {e(a['fact_en'])}</p>
    <p>🐾 {e(a['fact_fr'])}</p>
    <p class="far">{e(a['fact_ar'])} 🐾</p>
  </div>
  <div class="foot"><span>Point the Animal Book AR app at this page</span><span>Photo: {e(credit)}</span></div>
</section>"""


def doc(body):
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>{body}</body></html>'


def chrome(*args):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--allow-file-access-from-files", *args],
                   check=True, capture_output=True, timeout=120)


def main():
    animals = json.loads((APP_AR / "animals.json").read_text())
    credits = json.loads((ROOT / "tool" / "credits.json").read_text())
    (BOOK / "pages").mkdir(parents=True, exist_ok=True)
    (APP_AR / "pages").mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp())
    sections = []
    for i, a in enumerate(animals, 1):
        c = credits[a["id"] + "_photo"]
        credit = f"{c['artist']}, {c['license']}, Wikimedia Commons"
        sec = page_html(a, i, credit)
        sections.append(sec)
        f = tmp / f"{a['id']}.html"
        f.write_text(doc(sec))
        out = BOOK / "pages" / f"{a['id']}.png"
        chrome(f"--window-size={PAGE_W},{PAGE_H}", f"--force-device-scale-factor={SCALE}",
               f"--screenshot={out}", f.as_uri())
        with Image.open(out) as im:
            im = im.convert("RGB")
            im.thumbnail((900, 900 * PAGE_H // PAGE_W + 1))
            im.save(APP_AR / "pages" / f"{a['id']}.jpg", quality=85, optimize=True)
        print("page", out.relative_to(ROOT))
    book = tmp / "book.html"
    book.write_text(doc("".join(sections)))
    pdf = BOOK / "animal-book.pdf"
    chrome(f"--print-to-pdf={pdf}", "--no-pdf-header-footer", book.as_uri())
    print("book", pdf.relative_to(ROOT))


if __name__ == "__main__":
    main()
