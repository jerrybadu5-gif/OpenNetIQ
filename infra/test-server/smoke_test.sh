#!/bin/sh
# Verifies a running speed-test server: smoke_test.sh [base_url]
# Default base URL: http://127.0.0.1:8080. FTP checks run when FTP_URL
# (e.g. ftp://127.0.0.1:21) and FTP_PASSWORD are set (FTP_USER default onq). POSIX sh + curl only, so it also
# runs inside the curlimages/curl container (see docs/features/test-server).
set -eu

BASE="${1:-http://127.0.0.1:8080}"
fail=0

c() { curl -sS --max-time 30 -k "$@"; }

check() { # name, expected, actual
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    fail=1
  fi
}

has() { # name, pattern, text
  if printf '%s' "$3" | grep -qi "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}

lacks() { # name, pattern, text
  if printf '%s' "$3" | grep -qi "$2"; then echo "FAIL $1"; fail=1; else echo "ok   $1"; fi
}

check "health" "ok" "$(c "$BASE/health" || true)"

check "garbage 100 MiB" "104857600" \
  "$(c -o /dev/null -w '%{size_download}' "$BASE/backend/garbage.php?ckSize=100" || true)"

check "garbage content type" "application/octet-stream" \
  "$(c -o /dev/null -w '%{content_type}' "$BASE/backend/garbage.php?ckSize=100" || true)"

# Incompressible: gzip must not shrink a 1 MiB sample by more than 1 %.
sample=$(c -r 0-1048575 "$BASE/backend/garbage.php" | gzip -c | wc -c || echo 0)
if [ "$sample" -gt 1038090 ]; then echo "ok   garbage incompressible"; else echo "FAIL garbage compressible ($sample)"; fail=1; fi

headers=$(c -D - -o /dev/null "$BASE/backend/garbage.php" | tr -d '\r' || true)
has "no-store header" '^cache-control: no-store' "$headers"
lacks "no content-encoding" '^content-encoding' "$headers"
check "server header hides version" "server: nginx" \
  "$(printf '%s\n' "$headers" | grep -i '^server:' | tr '[:upper:]' '[:lower:]' || true)"

code=$(head -c 20971520 /dev/urandom | c -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/octet-stream' --data-binary @- "$BASE/backend/empty.php" || true)
check "upload 20 MiB" "200" "$code"

check "CORS preflight" "204" "$(c -o /dev/null -w '%{http_code}' -X OPTIONS "$BASE/backend/empty.php" || true)"
has "CORS header" '^access-control-allow-origin: \*' "$(c -D - -o /dev/null -X OPTIONS "$BASE/backend/empty.php" | tr -d '\r' || true)"

has "getIP json" '"processedString":"' "$(c "$BASE/backend/getIP.php" || true)"
check "ping" "204" "$(c -o /dev/null -w '%{http_code}' "$BASE/backend/ping" || true)"
check "unknown path" "404" "$(c -o /dev/null -w '%{http_code}' "$BASE/nope" || true)"

if [ -n "${FTP_URL:-}" ] && [ -n "${FTP_PASSWORD:-}" ]; then
  fu="${FTP_USER:-onq}:$FTP_PASSWORD"
  f() { curl -sS --max-time 120 -u "$fu" "$@"; }
  check "ftp download 5 MB" "5242880" "$(f -o /dev/null -w '%{size_download}' "$FTP_URL/download/5MB.bin" || true)"
  check "ftp download 100 MB" "104857600" "$(f -o /dev/null -w '%{size_download}' "$FTP_URL/download/100MB.bin" || true)"
  name="smoke-$$.bin"
  check "ftp upload 5 MB" "5242880" "$(head -c 5242880 /dev/urandom | f -T - -o /dev/null -w '%{size_upload}' "$FTP_URL/upload/$name" || true)"
  f -o /dev/null -Q "DELE upload/$name" "$FTP_URL/" || { echo "FAIL ftp delete"; fail=1; }
  check "ftp download read-only" "550" "$(printf x | f -T - -o /dev/null -w '%{response_code}' "$FTP_URL/download/x.bin" 2>/dev/null || true)"
  check "ftp wrong password" "530" "$(curl -sS --max-time 20 -u "${FTP_USER:-onq}:wrong" -o /dev/null -w '%{response_code}' "$FTP_URL/download/" 2>/dev/null || true)"
fi

if [ "$fail" -ne 0 ]; then echo "SMOKE TEST FAILED"; exit 1; fi
echo "SMOKE TEST PASSED"
