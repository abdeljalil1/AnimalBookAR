#!/usr/bin/env python3
"""Renders a sticker of every book item's 3D model for the map stops.

    python3 tool/make_stickers.py [--only=<book id>]

Opens tool/make_stickers.html in headless Chrome (three.js renders each model
as in the AR view, on a transparent background), then crops each picture to
the model and writes <thumbsDir>/<id>_sticker.png (256 x 256) for every book
in app/assets/ar/books.json. Run it again after changing a model.
"""
import http.server
import shutil
import subprocess
import sys
import threading
import urllib.parse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ONLY = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")), "")
done = threading.Event()
written = []


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(AR), **kw)

    def do_GET(self):
        if self.path.startswith("/__page"):
            body = (ROOT / "tool" / "make_stickers.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path.startswith("/__save?path="):
            out = (ROOT / urllib.parse.unquote(self.path.split("=", 1)[1])).resolve()
            if str(out).startswith(str(ROOT / "app" / "assets")) and out.name.endswith("_sticker.png"):
                out.write_bytes(data)
                written.append(out)
        elif self.path == "/__done":
            done.set()
        self.send_response(204)
        self.end_headers()

    def log_message(self, *a):
        pass


def crop(f):
    """Trim to the model (plus a margin), centre it on a square, 256 px."""
    with Image.open(f) as im:
        im = im.convert("RGBA")
        box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if not box:
            return
        im = im.crop(box)
        side = int(max(im.size) * 1.08)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(im, ((side - im.width) // 2, side - im.height - int(side * 0.04)))  # stands on the bottom
        sq.resize((256, 256), Image.LANCZOS).save(f, optimize=True)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = ROOT / "tool" / ".chrome-profile-stickers"
    query = f"?only={ONLY}" if ONLY else ""
    chrome = subprocess.Popen(
        [CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
         f"--user-data-dir={profile}", "--remote-debugging-port=0",
         f"http://127.0.0.1:{server.server_address[1]}/__page{query}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if not done.wait(timeout=900):
            sys.exit("timed out")
    finally:
        chrome.terminate()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    for f in written:
        crop(f)
    print(f"wrote {len(written)} stickers")


if __name__ == "__main__":
    main()
