# Speed-Test Server — API

Base: `http://<host>:8080/` or `https://<host>:8443/` (map to 80/443 in production).

| Method | Path | Response |
|---|---|---|
| GET | `/` | `200` text identifying the server and method |
| GET | `/health` | `200 ok` |
| GET | `/backend/garbage.php[?ckSize=N]` | `200`, `application/octet-stream`, `SPEEDTEST_GARBAGE_MIB` MiB (default 104 857 600 bytes) |
| POST | `/backend/empty.php` | `200`, empty; request body up to 64 MiB discarded |
| GET | `/backend/getIP.php` | `200` `{"processedString":"<client ip>","rawIspInfo":""}` |
| GET | `/backend/ping` | `204` |
| OPTIONS | `/backend/garbage.php`, `/backend/empty.php` | `204` (CORS preflight) |
| any | other | `404` |

Headers on every response: `Cache-Control: no-store, no-cache, must-revalidate, max-age=0`, `Access-Control-Allow-Origin: *`, no `Content-Encoding`, `Server: nginx` (no version). HTTPS adds `Strict-Transport-Security`.

## Configuration
| Variable | Default | Values |
|---|---|---|
| `HTTP_PORT` / `HTTPS_PORT` | 8080 / 8443 | host ports |
| `SPEEDTEST_GARBAGE_MIB` | 100 | 1..1024 |
| `SPEEDTEST_HTTPS` | auto | `auto`, `required`, `off` |
| `SPEEDTEST_ACCESS_LOG` | off | `on`, `off` |
