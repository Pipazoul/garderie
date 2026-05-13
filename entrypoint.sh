#!/bin/bash

# Set default ports
export NGINX_PORT="${NGINX_PORT:-80}"
export PB_PORT="${PB_PORT:-8090}"
export WEBDAV_PORT="${WEBDAV_PORT:-8889}"

# Generate nginx config from template
envsubst '${NGINX_PORT} ${PB_PORT} ${WEBDAV_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Seed default PocketBase hooks if hooks folder is empty
if [ -d /pb_hooks ] && [ -z "$(ls -A /pb_hooks 2>/dev/null)" ]; then
    cp /pb_hooks_default/* /pb_hooks/ 2>/dev/null || true
fi

# Create PocketBase admin on first run
if [ -n "$PB_ADMIN_EMAIL" ] && [ -n "$PB_ADMIN_PASSWORD" ]; then
    pocketbase superuser create "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" --dir /pb_data 2>/dev/null || true
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
