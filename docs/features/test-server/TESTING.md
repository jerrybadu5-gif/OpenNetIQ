# Speed-Test Server — Testing

## Automated (`.github/workflows/test-server.yml`, on changes to `infra/test-server/**`)
1. `docker compose up -d --build --wait` (health check must pass).
2. `smoke_test.sh` over HTTP: health, 100 MiB download, content type, incompressible payload, no-store, no content-encoding, server version hidden, 20 MiB upload, CORS preflight + header, getIP JSON, ping 204, unknown path 404.
3. Throwaway self-signed certificate, `SPEEDTEST_HTTPS=required`, same smoke test over HTTPS (HTTP/2).

## Local
```bash
cd infra/test-server
docker compose up -d --build --wait
./smoke_test.sh                       # HTTP
./smoke_test.sh https://127.0.0.1:8443  # after adding certs
docker compose down
```
On Windows (Docker Desktop), WSL's `127.0.0.1` does not reach ports published on Windows, so run the smoke test in a small container on the compose network instead (PowerShell):
```powershell
docker run --rm --network test-server_default -v "${PWD}:/t:ro" curlimages/curl:8.16.0 sh /t/smoke_test.sh http://speedtest:8080
```
The same command works on Linux and macOS.

### Troubleshooting
- `Bind for 0.0.0.0:8443 failed: port is already allocated` (or 8080): another program uses that host port. Pick another one, e.g. PowerShell `$env:HTTPS_PORT="9443"` or `HTTPS_PORT=9443` in `.env`, then `docker compose up -d --wait` again. The smoke test only needs the HTTP port (8080 by default; pass the URL if you change it).

## With the app
Phone and server on the same network (dev flavor allows HTTP): Speed test -> `http://<server IP>:8080/backend/` -> Start. Production (prod flavor): `https://<domain>/backend/`.

## Verified while building (sandbox)
- Smoke test passed over HTTP and HTTPS.
- `SPEEDTEST_HTTPS=required` without certificates and an invalid `SPEEDTEST_GARBAGE_MIB` both stop the container with a clear message.
- App engine (Kotlin, `http-mc-1.0`) against the container: status `ok`, 8.4 Gbit/s down, 5.2 Gbit/s up over loopback.
