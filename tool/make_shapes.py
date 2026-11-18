#!/usr/bin/env python3
"""Builds the 3D letters (letter books) and colour scenes (Colors book).

    python3 tool/make_shapes.py

Run after tool/make_learning_books.py (--only=letters|colors|algeria builds one book). It opens tool/make_shapes.html in
headless Chrome (three.js builds the shapes there) and writes:
  app/assets/ar/books/letters_ar/models/*.glb  one extruded letter per page
  app/assets/ar/books/colors/models/*.glb      four objects in each colour
  app/assets/ar/books/*/thumbs/*.jpg           thumbnails for the map
  tool/photos/colors/*.png                     the colour pictures for the pages
and the parts (the objects of each colour scene) in colors/items.json.
Needs Chrome, and the three.js add-ons in tool/.cache/three (fetched from
unpkg on first run).
"""
import http.server
import io
import json
import shutil
import subprocess
import sys
import threading
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar"
BOOKS = AR / "books"
CACHE = ROOT / "tool" / ".cache" / "three"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ADDONS = ["loaders/TTFLoader.js", "loaders/FontLoader.js", "geometries/TextGeometry.js", "libs/opentype.module.js",
          "exporters/GLTFExporter.js", "utils/TextureUtils.js"]

# The objects in each colour scene, and their names.
OBJECTS = {
    "ball": ("Ball", "Balle", "كرة", "la balle", "الكرة"),
    "star": ("Star", "Étoile", "نجمة", "l'étoile", "النجمة"),
    "heart": ("Heart", "Cœur", "قلب", "le cœur", "القلب"),
    "balloon": ("Balloon", "Ballon", "بالون", "le ballon", "البالون"),
    "cube": ("Block", "Cube", "مكعب", "le cube", "المكعب"),
    "flower": ("Flower", "Fleur", "زهرة", "la fleur", "الزهرة"),
    "cup": ("Cup", "Tasse", "كوب", "la tasse", "الكوب"),
    "hat": ("Party hat", "Chapeau", "قبعة", "le chapeau", "القبعة"),
    "fish": ("Fish", "Poisson", "سمكة", "le poisson", "السمكة"),
}
SETS = [["ball", "star", "balloon", "cup"], ["heart", "fish", "hat", "cube"], ["flower", "ball", "star", "hat"],
        ["balloon", "cube", "fish", "heart"], ["cup", "flower", "heart", "ball"]]
# Four spots per scene: x, z, scale (different on each page, so each page looks different to the tracker).
LAYOUTS = [
    [[-0.85, 0.25, 1.0], [0.05, -0.35, 1.1], [0.85, 0.2, 1.0], [0.1, 0.55, 0.85]],
    [[-0.8, -0.3, 1.1], [0.6, -0.35, 1.0], [-0.2, 0.5, 0.9], [0.9, 0.45, 0.85]],
    [[-0.9, 0.4, 0.9], [-0.25, -0.4, 1.05], [0.55, 0.15, 1.1], [1.05, -0.45, 0.85]],
]
ONLY = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")), "")  # letters | colors | algeria
done = threading.Event()
result = {}


def config():
    books = {b: json.loads((BOOKS / b / "items.json").read_text()) for b in ["letters_ar", "colors"]}
    colors = []
    for i, it in enumerate(books["colors"]):
        colors.append({"id": it["id"], "cid": it["id"].removeprefix("color_"), "model": it["model"],
                       "color": it["color"], "objects": SETS[i % len(SETS)]})
    dz = json.loads((BOOKS / "algeria" / "items.json").read_text())
    algeria = [{"id": it["id"], "key": it["id"].removeprefix("dz_"), "model": it["model"]} for it in dz]
    return {"only": ONLY, "algeria": algeria, "letters_ar": books["letters_ar"], "colors": colors, "layouts": LAYOUTS}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(AR), **kw)

    def send_bytes(self, body, kind):
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/__page":
            return self.send_bytes((ROOT / "tool" / "make_shapes.html").read_bytes(), "text/html; charset=utf-8")
        if p == "/__config":
            return self.send_bytes(json.dumps(config(), ensure_ascii=False).encode(), "application/json")
        if p == "/__algeria.js":
            return self.send_bytes((ROOT / "tool" / "make_shapes_algeria.js").read_bytes(), "text/javascript")
        if p.startswith("/__three/"):
            return self.send_bytes((CACHE / "examples" / "jsm" / p[len("/__three/"):]).read_bytes(), "text/javascript")
        if p.startswith("/__fonts/"):
            return self.send_bytes((ROOT / "app" / "assets" / "fonts" / Path(p).name).read_bytes(), "font/ttf")
        super().do_GET()

    def do_POST(self):
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path.startswith("/__save?path="):
            rel = urllib.request.unquote(self.path.split("=", 1)[1])
            out = (ROOT / rel).resolve()
            if not (str(out).startswith(str(BOOKS)) or str(out).startswith(str(ROOT / "tool" / "photos"))):
                self.send_response(403)
                self.end_headers()
                return
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(data)
            print("  wrote", rel, flush=True)
        elif self.path == "/__done":
            result["done"] = json.loads(data)
            done.set()
        self.send_response(204)
        self.end_headers()

    def log_message(self, *a):
        pass


def fetch_addons():
    for f in ADDONS:
        out = CACHE / "examples" / "jsm" / f
        if not out.exists():
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(urllib.request.urlopen(f"https://unpkg.com/three@0.160.0/examples/jsm/{f}").read())


def finish():
    # thumbnails as JPEG (the app's thumbAsset), on their own background
    for png in BOOKS.glob("*/thumbs/*.png"):
        with Image.open(png) as im:
            im.convert("RGB").save(png.with_suffix(".jpg"), quality=88)
        png.unlink()
    # the measured parts of the Algeria models
    f = BOOKS / "algeria" / "items.json"
    items = json.loads(f.read_text())
    spots = {m["id"]: m["at"] for m in result["done"].get("algeria", [])}
    for it in items:
        for p in it["parts"]:
            if p["id"] in spots.get(it["id"], {}):
                p["at"] = spots[it["id"]][p["id"]]
    f.write_text(json.dumps(items, ensure_ascii=False, indent=1))
    if not result["done"]["colors"]:
        return
    # the measured parts of each colour scene
    f = BOOKS / "colors" / "items.json"
    items = json.loads(f.read_text())
    parts = {c["id"]: c["parts"] for c in result["done"]["colors"]}
    for it in items:
        it["parts"] = [{"id": p["id"], "en": OBJECTS[p["id"]][0], "fr": OBJECTS[p["id"]][1], "ar": OBJECTS[p["id"]][2],
                        "fr_def": OBJECTS[p["id"]][3], "ar_def": OBJECTS[p["id"]][4], "at": p["at"]}
                       for p in parts[it["id"]]]
    f.write_text(json.dumps(items, ensure_ascii=False, indent=1))
    print("parts written to", f.relative_to(ROOT))


def main():
    fetch_addons()
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = ROOT / "tool" / ".chrome-profile-shapes"
    chrome = subprocess.Popen(
        [CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
         f"--user-data-dir={profile}", "--remote-debugging-port=0",
         f"http://127.0.0.1:{server.server_address[1]}/__page"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if not done.wait(timeout=600):
            sys.exit("timed out")
    finally:
        chrome.terminate()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    finish()


if __name__ == "__main__":
    main()
