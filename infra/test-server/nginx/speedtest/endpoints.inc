# Endpoints used by the OpenNetIQ engine (method http-mc-1.0) and
# LibreSpeed web clients. Shared by the HTTP and HTTPS servers.
add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
add_header Access-Control-Allow-Origin "*" always;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
add_header Access-Control-Allow-Headers "Content-Encoding, Content-Type" always;

location = / {
    default_type text/plain;
    return 200 "OpenNetIQ speed-test server (method http-mc-1.0)\n";
}

location = /health {
    access_log off;
    default_type text/plain;
    return 200 "ok\n";
}

# Download: a fixed pre-generated block of incompressible data. ckSize is
# accepted but ignored; clients simply request again when it is consumed.
location = /backend/garbage.php {
    if ($request_method = OPTIONS) { return 204; }
    root /tmp/opennetiq;
    try_files /garbage.bin =503;
}

# Upload sink: the body is read and discarded.
location = /backend/empty.php {
    if ($request_method = OPTIONS) { return 204; }
    return 200;
}

# The client's own address, for diagnostics (never logged or stored).
location = /backend/getIP.php {
    default_type application/json;
    return 200 '{"processedString":"$remote_addr","rawIspInfo":""}';
}

# Minimal response for HTTP latency probes (#21).
location = /backend/ping {
    return 204;
}

location / {
    return 404;
}
