from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GodotWebHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        if path.endswith(".pck"):
            return "application/octet-stream"
        return super().guess_type(path)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1] / "build" / "web"
    import os

    os.chdir(root)
    server = ThreadingHTTPServer(("127.0.0.1", 8060), GodotWebHandler)
    print("Serving TrainsTrainsTrains web build at http://127.0.0.1:8060/")
    server.serve_forever()
