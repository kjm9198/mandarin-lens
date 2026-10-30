"""Explicit local protocol fixture. Does not certify LM Studio/Bionic inference."""
import json
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        assert self.path == "/v1/models"
        self.reply({"data": [{"id": "fixture-only"}]})

    def do_POST(self):
        assert self.path == "/v1/chat/completions"
        payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        assert payload["model"] == "fixture-only" and payload["stream"] is False
        self.reply({"choices": [{"message": {"content": "Local adapter fixture passed."}}]})

    def reply(self, payload):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())


server = HTTPServer(("127.0.0.1", 28078), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "/tmp/lens-feature-smoke", "--api-fixture"], check=True, timeout=30)
finally:
    server.shutdown()
    server.server_close()
