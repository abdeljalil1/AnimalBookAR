#!/usr/bin/env python3
"""Compiles the book pages (book/pages/*.png) into app/assets/ar/targets.mind (MindAR image targets).

Run after tool/make_pages.py whenever a page changes:
    python3 tool/compile_targets.py

It serves app/assets/ar on a local port, opens tool/compile_targets.html in
headless Chrome (MindAR's compiler runs in the browser) and saves the result.
Target order follows animals.json, so target index i is animal i.
"""
import http.server
import shutil
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar"
OUT = AR / "targets.mind"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
done = threading.Event()
result = {}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(AR), **kw)

    def do_GET(self):
        if self.path.startswith("/__pages/"):
            f = ROOT / "book" / "pages" / Path(self.path).name
            self.send_response(200 if f.is_file() else 404)
            self.send_header("Content-Type", "image/png")
            self.end_headers()
            if f.is_file():
                self.wfile.write(f.read_bytes())
            return
        if self.path.startswith("/__compile.html"):
            body = (ROOT / "tool" / "compile_targets.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        result["ok" if self.path == "/__result" else "error"] = data
        self.send_response(204)
        self.end_headers()
        done.set()

    def log_message(self, *a):
        pass


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = ROOT / "tool" / ".chrome-profile"
    chrome = subprocess.Popen(
        [CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
         f"--user-data-dir={profile}", "--remote-debugging-port=0",
         f"http://127.0.0.1:{port}/__compile.html"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if not done.wait(timeout=600):
            sys.exit("timed out after 10 minutes")
    finally:
        chrome.terminate()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    if "error" in result:
        sys.exit("compile failed:\n" + result["error"].decode())
    OUT.write_bytes(result["ok"])
    print(f"wrote {OUT.relative_to(ROOT)} ({len(result['ok'])} bytes)")


if __name__ == "__main__":
    main()
