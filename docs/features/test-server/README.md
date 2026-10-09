# Speed-Test Server

Self-hosted reference server for the OpenNetIQ speed test (method `http-mc-1.0`, ADR-007, ADR-016). Closes #20.

## What it is
A hardened nginx container serving LibreSpeed-compatible endpoints:

| Endpoint | Use |
|---|---|
| `GET /backend/garbage.php` | Download: 100 MiB of incompressible data per request (size via `SPEEDTEST_GARBAGE_MIB`) |
| `POST /backend/empty.php` | Upload sink (body discarded, up to 64 MiB per request) |
| `GET /backend/getIP.php` | The client's own address (diagnostics) |
| `GET /backend/ping` | `204` for HTTP latency probes (#21) |
| `GET /health` | `ok` for monitoring / Docker health check |

App server URL: `https://<host>/backend/` (or `http://<host>:8080/backend/` for the dev flavor on a LAN).

## Quick start
```bash
cd infra/test-server
cp .env.example .env            # ports, HTTPS mode, logging
docker compose up -d --build --wait
./smoke_test.sh http://127.0.0.1:8080
# Windows / any OS, from a container on the compose network:
# docker run --rm --network test-server_default -v "${PWD}:/t:ro" curlimages/curl:8.16.0 sh /t/smoke_test.sh http://speedtest:8080
```

## Production deployment (regulator reference server)
1. **Host**: Linux VM or bare metal with Docker Engine + Compose v2, sized per the table below, in-country and **neutral**: a national IXP or a data centre peered with every operator under test, not inside one operator's network.
2. **DNS**: e.g. `speedtest.nicta.gov.pg` -> server public IP.
3. **Certificate** (Let's Encrypt, standalone mode, before starting the container):
   ```bash
   sudo certbot certonly --standalone -d speedtest.example.org
   sudo cp /etc/letsencrypt/live/speedtest.example.org/{fullchain,privkey}.pem infra/test-server/certs/
   sudo chown 101:101 infra/test-server/certs/*.pem && sudo chmod 640 infra/test-server/certs/privkey.pem
   ```
   Renewal: a cron/systemd timer running `certbot renew`, copying the files again and `docker compose restart`.
4. **.env**: `HTTP_PORT=80`, `HTTPS_PORT=443`, `SPEEDTEST_HTTPS=required`.
5. `docker compose up -d --build --wait`, then `./smoke_test.sh https://speedtest.example.org`.
6. **Firewall**: allow TCP 80/443 only (80 can be closed after certificates are issued if only HTTPS is used).
7. **Kernel tuning** (host, `/etc/sysctl.d/90-speedtest.conf`):
   ```
   net.core.default_qdisc = fq
   net.ipv4.tcp_congestion_control = bbr
   net.core.rmem_max = 67108864
   net.core.wmem_max = 67108864
   net.ipv4.tcp_rmem = 4096 131072 67108864
   net.ipv4.tcp_wmem = 4096 131072 67108864
   net.core.somaxconn = 4096
   ```
   Use the **same** TCP settings on every reference server and record them in the deployment record: congestion control influences results.
8. For 10 Gbit/s, run with `network_mode: host` (avoids Docker's port forwarding) and an even larger `worker_connections` if needed.

## Sizing
A single test saturates the client's link for 12 s per direction. The server uplink must exceed the fastest client plus the expected concurrency.

| Profile | Uplink | vCPU | RAM | Concurrent tests at 100 Mbit/s |
|---|---|---|---|---|
| Minimum (pilot, 4G) | **>= 1 Gbit/s** dedicated | 4 | 2 GB | ~8 |
| Recommended (4G + 5G) | 10 Gbit/s | 8 | 4 GB | ~80 |

- nginx sends from page cache with `sendfile`; plain HTTP needs < 1 core per Gbit/s. TLS adds roughly 1 core per 2–4 Gbit/s (AES-NI).
- Data volume: a test moves about (download + upload rate) x 12 s. 1 000 tests/day averaging 50 Mbit/s down + 20 Mbit/s up is about 105 GB/day; budget transit accordingly.
- Bench in this repo's sandbox: the app engine measured 8.4 Gbit/s down / 5.2 Gbit/s up against one container over loopback, so the server is not the limit at 1 Gbit/s.

## Security and privacy
- Non-root (uid 101), read-only root filesystem, all capabilities dropped, `no-new-privileges`, base image pinned by digest (Dependabot keeps it current).
- **No access logs by default** (client IPs are personal data). Set `SPEEDTEST_ACCESS_LOG=on` only with a documented purpose and retention.
- No rate limiting on the endpoints (it would distort measurements); restrict access at the firewall if the server must not be public.

## Not included (follow-up)
- **M-Lab ndt7 fallback** in the app is deferred (ADR-016): M-Lab publishes the client IP address with every test, so it needs explicit user consent (#24) before it can be offered.
