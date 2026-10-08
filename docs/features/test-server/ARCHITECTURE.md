# Speed-Test Server — Architecture

```
infra/test-server/
  Dockerfile                      nginx-unprivileged 1.29.8 (pinned digest), uid 101
  docker-compose.yml              read-only rootfs, tmpfs /tmp, cap_drop ALL, health check
  nginx/nginx.conf                sendfile, tcp_nopush/nodelay, no gzip, keep-alive 10 000 req
  nginx/speedtest/endpoints.inc   shared locations (HTTP + HTTPS)
  nginx/speedtest/http.conf.template, https.conf.template
  entrypoint/40-opennetiq-speedtest.sh
  smoke_test.sh                   endpoint checks (CI + operators)
```

## Start-up (entrypoint, runs as uid 101)
1. Writes `SPEEDTEST_GARBAGE_MIB` MiB from `/dev/urandom` to `/tmp/opennetiq/garbage.bin` (incompressible, not stored in the image).
2. Renders the HTTP server (and the HTTPS server when `certs/fullchain.pem` + `privkey.pem` are present; `SPEEDTEST_HTTPS=required` refuses to start without them). IPv6 listeners only when the host has IPv6.
3. Access logging off unless `SPEEDTEST_ACCESS_LOG=on`.

## Design choices (ADR-016)
- nginx instead of the PHP LibreSpeed backend: static file + `sendfile` reaches line rate on modest CPUs; no interpreter in the data path.
- `garbage.php` ignores `ckSize`: the OpenNetIQ engine requests 100 MiB and re-requests until the 12 s window ends; LibreSpeed browser clients behave the same way.
- Upload: nginx reads and discards the body (`return 200`).
- Endpoint paths are LibreSpeed's, so existing LibreSpeed web clients can use the same server.
