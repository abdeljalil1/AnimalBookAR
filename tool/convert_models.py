#!/usr/bin/env python3
"""Converts FBX animal models (e.g. Quaternius CC0 packs) to GLB for the app.

    python3 tool/convert_models.py <out_dir> <file.fbx>=<name> [...]
    e.g. python3 tool/convert_models.py app/assets/ar/models "packs/Cow.fbx=Cow"

Runs three.js's FBXLoader + GLTFExporter in headless Chrome (no Blender
needed). Fetches three.js 0.160 from npm into tool/.cache the first time.
"""
import http.server
import json
import shutil
import subprocess
import sys
import tarfile
import threading
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tool" / ".cache"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def three_dir():
    pkg = CACHE / "three" / "package"
    if not pkg.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        subprocess.run(["npm", "pack", "three@0.160.0", "--silent"], cwd=CACHE, check=True, capture_output=True)
        with tarfile.open(CACHE / "three-0.160.0.tgz") as t:
            t.extractall(CACHE / "three", filter="data")
    return pkg


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out_dir = Path(sys.argv[1]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    jobs, sources = [], {}
    for arg in sys.argv[2:]:
        src, name = arg.rsplit("=", 1)
        sources[Path(src).name] = Path(src).resolve()
        jobs.append({"src": Path(src).name, "out": f"{name}.glb"})
    three = three_dir()
    done = threading.Event()
    result = {"errors": []}

    class H(http.server.SimpleHTTPRequestHandler):
        def send(self, body, ctype):
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urllib.parse.unquote(self.path.split("?")[0])
            if path == "/":
                return self.send((ROOT / "tool" / "convert_models.html").read_bytes(), "text/html")
            if path == "/__jobs":
                return self.send(json.dumps(jobs).encode(), "application/json")
            if path.startswith("/__fbx/"):
                return self.send(sources[path[7:]].read_bytes(), "application/octet-stream")
            if path.startswith("/__three/"):
                f = (three / path[9:]).resolve()
                if three in f.parents and f.is_file():
                    return self.send(f.read_bytes(), "text/javascript")
            # textures referenced by the FBX files, looked up next to them
            for src in sources.values():
                f = src.parent / Path(path).name
                if f.is_file():
                    return self.send(f.read_bytes(), "image/png")
            self.send_response(404)
            self.end_headers()

        def do_POST(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            path = urllib.parse.unquote(self.path)
            if path.startswith("/__out/"):
                (out_dir / path[7:]).write_bytes(body)
            elif path == "/__err":
                result["errors"].append(body.decode())
            elif path == "/__done":
                result["log"] = body.decode()
                done.set()
            self.send_response(204)
            self.end_headers()

        def log_message(self, *a):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = CACHE / "chrome-profile"
    chrome = subprocess.Popen([CHROME, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                               f"--user-data-dir={profile}", "--remote-debugging-port=0",
                               f"http://127.0.0.1:{server.server_address[1]}/"],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        done.wait(timeout=600)
    finally:
        chrome.terminate()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    print(result.get("log", "timed out"))
    for e in result["errors"]:
        print("ERROR", e[:400])
    sys.exit(1 if result["errors"] or "log" not in result else 0)


if __name__ == "__main__":
    main()
