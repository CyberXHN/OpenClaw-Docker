#!/bin/bash
set -e

APP_DIR=/app
BACKUP_FILE=/openclaw-app.tar.gz

# Initialize /app directory: extract from factory backup
# Runs as node user, no chown needed (Dockerfile already set directory permissions)
if [ ! -f "${APP_DIR}/openclaw.mjs" ]; then
    echo "==> /app is empty, initializing OpenClaw from factory backup..."
    tar -xzf "${BACKUP_FILE}" -C /
    echo "==> OpenClaw initialization complete. Version: $(node -p "require('${APP_DIR}/package.json').version" 2>/dev/null || echo 'unknown')"
fi

# Execute CMD (exec ensures process replacement, correct signal handling)
exec "$@"
