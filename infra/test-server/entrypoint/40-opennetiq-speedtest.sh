#!/bin/sh
# Prepares the read-only container at start: download payload, TLS server
# (when certificates are mounted) and logging. Runs as uid 101.
set -eu

state=/tmp/opennetiq
mkdir -p "$state"

mib="${SPEEDTEST_GARBAGE_MIB:-100}"
case "$mib" in
  ''|*[!0-9]*) echo "opennetiq: SPEEDTEST_GARBAGE_MIB must be a number" >&2; exit 1 ;;
esac
if [ "$mib" -lt 1 ] || [ "$mib" -gt 1024 ]; then
  echo "opennetiq: SPEEDTEST_GARBAGE_MIB must be 1..1024" >&2
  exit 1
fi
# Incompressible payload, regenerated at every start (no image bloat).
head -c "$((mib * 1024 * 1024))" /dev/urandom > "$state/garbage.bin"
echo "opennetiq: download payload ${mib} MiB ready"

# Listen on IPv6 too when the host supports it.
render() { # template -> output
  if [ -f /proc/net/if_inet6 ]; then
    sed 's|#ipv6 ||' "$1" > "$2"
  else
    grep -v '#ipv6' "$1" > "$2"
  fi
}
render /etc/nginx/speedtest/http.conf.template "$state/http.conf"

cert=/etc/nginx/certs/fullchain.pem
key=/etc/nginx/certs/privkey.pem
rm -f "$state"/https*.conf
case "${SPEEDTEST_HTTPS:-auto}" in
  off)
    echo "opennetiq: HTTPS disabled" ;;
  auto|required)
    if [ -r "$cert" ] && [ -r "$key" ]; then
      render /etc/nginx/speedtest/https.conf.template "$state/https.conf"
      echo "opennetiq: HTTPS enabled on 8443"
    elif [ "${SPEEDTEST_HTTPS}" = "required" ]; then
      echo "opennetiq: SPEEDTEST_HTTPS=required but $cert / $key are missing" >&2
      exit 1
    else
      echo "opennetiq: no certificates mounted, serving HTTP only"
    fi ;;
  *)
    echo "opennetiq: SPEEDTEST_HTTPS must be auto, required or off" >&2
    exit 1 ;;
esac

if [ "${SPEEDTEST_ACCESS_LOG:-off}" = "on" ]; then
  echo 'access_log /dev/stdout speedtest;' > "$state/logging.conf"
else
  echo 'access_log off;' > "$state/logging.conf"
fi
