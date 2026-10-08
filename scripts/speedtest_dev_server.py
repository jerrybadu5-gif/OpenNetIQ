#!/usr/bin/env python3
"""LibreSpeed-compatible speed-test server for development on a LAN.

Serves the endpoints the OpenNetIQ engine uses (method http-mc-1.0):
  GET  /backend/garbage.php?ckSize=N   N MiB of incompressible data
  POST /backend/empty.php              upload sink
  GET  /backend/getIP.php              client address (diagnostics)

Python 3.9+ standard library only. NOT for regulatory measurements: use the
production container (issue #20, ADR-007) on a server with >= 1 Gbps.

  python scripts/speedtest_dev_server.py --port 8080
  App server URL: http://<PC LAN IP>:8080/backend/   (dev flavor only)
"""
import argparse
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

CHUNK = os.urandom(1024 * 1024)
MAX_MIB = 1024


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # quieter console
        pass

    def _headers(self, status, length, content_type="application/octet-stream"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

    def do_GET(self):
        url = urlparse(self.path)
        if url.path.endswith("/garbage.php"):
            try:
                mib = int(parse_qs(url.query).get("ckSize", ["4"])[0])
            except ValueError:
                mib = 4
            mib = max(1, min(mib, MAX_MIB))
            self._headers(200, mib * len(CHUNK))
            try:
                for _ in range(mib):
                    self.wfile.write(CHUNK)
            except (BrokenPipeError, ConnectionResetError):
                pass  # client stopped at the end of the test
        elif url.path.endswith("/getIP.php"):
            body = self.client_address[0].encode()
            self._headers(200, len(body), "text/plain")
            self.wfile.write(body)
        elif url.path.endswith("/empty.php"):
            self._headers(200, 0)
        else:
            self._headers(404, 0)

    def do_POST(self):
        if not urlparse(self.path).path.endswith("/empty.php"):
            self._headers(404, 0)
            return
        remaining = int(self.headers.get("Content-Length", "0"))
        try:
            while remaining > 0:
                data = self.rfile.read(min(remaining, 65536))
                if not data:
                    break
                remaining -= len(data)
            self._headers(200, 0)
        except (BrokenPipeError, ConnectionResetError):
            pass  # upload cut at the end of the test


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.daemon_threads = True
    print(f"Speed-test dev server on http://{lan_ip()}:{args.port}/backend/  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
