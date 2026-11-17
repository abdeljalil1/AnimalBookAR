#!/usr/bin/env python3
"""Screenshots every model from the side and from above over a 10% grid.

Use it to place body parts ("parts" in app/assets/ar/animals.json):
    python3 tool/inspect_models.py           -> tool/test-output/models.png
    python3 tool/inspect_models.py --parts   -> same, with the parts as red dots
    python3 tool/inspect_models.py --only=fox,stork   -> just those animals
(The screenshot waits a fixed time, so with all five the last ones may be cut off.)
"""
import http.server
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AR = ROOT / "app" / "assets" / "ar"
OUT = ROOT / "tool" / "test-output"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(AR), **kw)

    def do_GET(self):
        if self.path.startswith("/__inspect.html"):
            body = (ROOT / "tool" / "inspect_models.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def log_message(self, *a):
        pass


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    parts = "--parts" in sys.argv
    only = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")), "")
    files = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--files=")), "")
    query = "?" + "&".join(x for x in ["parts" if parts else "", f"only={only}" if only else "",
                                       f"files={files}" if files else ""] if x)
    tag = only or "-".join(Path(f).stem for f in files.split(",")) if (only or files) else ""
    out = OUT / f"models{'-parts' if parts else ''}{'-' + tag.replace(',', '-') if tag else ''}.png"
    subprocess.run([CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                    "--hide-scrollbars", "--window-size=750,1260", "--virtual-time-budget=20000",
                    f"--screenshot={out}", f"http://127.0.0.1:{server.server_address[1]}/__inspect.html{query}"],
                   check=True, capture_output=True, timeout=180)
    server.shutdown()
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
