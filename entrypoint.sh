#!/bin/bash
set -e

APP_DIR=/app
BACKUP_FILE=/openclaw-app.tar.xz

# Initialize /app directory: extract from factory backup
# Runs as node user, no chown needed (Dockerfile pre-sets directory permissions)
if [ ! -f "${APP_DIR}/openclaw.mjs" ]; then
    echo "==> /app is empty, initializing OpenClaw from factory backup..."
    tar -xJf "${BACKUP_FILE}" -C /
    echo "==> OpenClaw initialized. Version: $(node -p "require('${APP_DIR}/package.json').version" 2>/dev/null || echo 'unknown')"
fi

# Execute CMD (exec ensures process replacement for proper signal handling)
exec "$@"
