# OpenNetIQ speed-test server (issue #20, ADR-007): LibreSpeed-compatible
# endpoints for method http-mc-1.0, served by nginx (sendfile, non-root).
FROM nginxinc/nginx-unprivileged:1.29.8-alpine@sha256:0c79d56aee561a1d81c63f00eee5fb5fe29279560cdc55e91425133104c7fbe6

LABEL org.opencontainers.image.title="opennetiq-speedtest-server" \
      org.opencontainers.image.description="LibreSpeed-compatible HTTP speed-test endpoints for OpenNetIQ (method http-mc-1.0)" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/jerrybadu5-gif/OpenNetIQ"

USER root
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/speedtest/ /etc/nginx/speedtest/
COPY --chmod=0755 entrypoint/40-opennetiq-speedtest.sh /docker-entrypoint.d/
USER 101

ENV SPEEDTEST_GARBAGE_MIB=100 \
    SPEEDTEST_HTTPS=auto \
    SPEEDTEST_ACCESS_LOG=off

EXPOSE 8080 8443
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
