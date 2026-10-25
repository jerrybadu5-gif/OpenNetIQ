"""OpenNetIQ FTP throughput server (spec v3 M14, NICTA QoS Rule 2022 Sch. 2 G8).

One virtual user (credentials from the environment). It serves read-only
incompressible files in /download ({5,10,20,50,100}MB.bin) and a writable
/upload whose files are deleted after FTP_UPLOAD_TTL_S. Runs as non-root;
RETR uses sendfile(2).
"""

from __future__ import annotations

import logging
import os
import sys
import threading
import time
from pathlib import Path

from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer

SIZES_MB = (5, 10, 20, 50, 100)
CHUNK = 1024 * 1024


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        sys.exit(f"{name} is required")
    return value


def make_files(download: Path) -> None:
    """Creates the download files once (random data, incompressible)."""
    download.mkdir(parents=True, exist_ok=True)
    for mb in SIZES_MB:
        path = download / f"{mb}MB.bin"
        if path.exists() and path.stat().st_size == mb * CHUNK:
            continue
        tmp = path.with_suffix(".tmp")
        with tmp.open("wb") as f:
            for _ in range(mb):
                f.write(os.urandom(CHUNK))
        tmp.replace(path)
    for p in download.iterdir():
        p.chmod(0o444)


def janitor(upload: Path, ttl_s: int) -> None:
    """Deletes uploads older than ttl_s (keeps the volume from filling)."""
    while True:
        cutoff = time.time() - ttl_s
        for p in upload.glob("*"):
            try:
                if p.is_file() and p.stat().st_mtime < cutoff:
                    p.unlink()
            except OSError:
                pass
        time.sleep(30)


def build_server(root: Path) -> FTPServer:
    user = env("FTP_USER", "onq")
    password = env("FTP_PASSWORD")
    if len(password) < 12:
        sys.exit("FTP_PASSWORD must have at least 12 characters")
    low, high = (int(x) for x in env("FTP_PASSIVE_PORTS", "30000-30009").split("-"))

    authorizer = DummyAuthorizer()
    # e=chdir l=list r=retrieve w=store (upload dir only) d=delete (upload dir only)
    authorizer.add_user(user, password, str(root), perm="elr")
    authorizer.override_perm(user, str(root / "upload"), perm="elrwd", recursive=True)

    handler = FTPHandler
    handler.authorizer = authorizer
    handler.passive_ports = range(low, high + 1)
    handler.use_sendfile = True
    handler.banner = "OpenNetIQ FTP test server"
    handler.max_login_attempts = 3
    public = os.environ.get("FTP_PUBLIC_ADDRESS")
    if public:
        handler.masquerade_address = public
    handler.timeout = int(env("FTP_IDLE_TIMEOUT_S", "120"))

    server = FTPServer(("0.0.0.0", int(env("FTP_PORT", "2121"))), handler)
    server.max_cons = int(env("FTP_MAX_CONNECTIONS", "32"))
    server.max_cons_per_ip = int(env("FTP_MAX_PER_IP", "8"))
    return server


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    root = Path(env("FTP_ROOT", "/srv/ftp"))
    make_files(root / "download")
    (root / "upload").mkdir(parents=True, exist_ok=True)
    threading.Thread(
        target=janitor,
        args=(root / "upload", int(env("FTP_UPLOAD_TTL_S", "600"))),
        daemon=True,
    ).start()
    build_server(root).serve_forever(handle_exit=True)


if __name__ == "__main__":
    main()
