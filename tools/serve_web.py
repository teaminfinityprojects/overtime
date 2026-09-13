#!/usr/bin/env python3
"""Sirve el export HTML5 (build/web) en local con las cabeceras que Godot necesita:
    python3 tools/serve_web.py [puerto]      → http://localhost:8060
"""
import http.server, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT), **k)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print(f"sirviendo {ROOT} en http://localhost:{PORT}", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
