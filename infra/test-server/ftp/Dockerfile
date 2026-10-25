# OpenNetIQ FTP throughput server (spec v3 M14). pyftpdlib (MIT), non-root.
# Pin the base image by digest when deploying (docker buildx imagetools inspect).
FROM python:3.12-alpine

LABEL org.opencontainers.image.title="opennetiq-ftp-server" \
      org.opencontainers.image.description="FTP download/upload endpoints for OpenNetIQ FTP throughput tests (NICTA QoS Rule 2022 Schedule 2)" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/jerrybadu5-gif/OpenNetIQ"

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt \
 && adduser -D -H -u 10001 ftp-onq \
 && mkdir -p /srv/ftp && chown ftp-onq /srv/ftp
COPY onq_ftpd.py /app/onq_ftpd.py

USER 10001
ENV FTP_ROOT=/srv/ftp FTP_PORT=2121 FTP_PASSIVE_PORTS=30000-30009 PYTHONUNBUFFERED=1
EXPOSE 2121 30000-30009
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import socket; s=socket.create_connection(('127.0.0.1', 2121), 2); print(s.recv(64))" || exit 1
ENTRYPOINT ["python", "/app/onq_ftpd.py"]
