#!/bin/bash
set -e

NPM_GLOBAL_DIR=/home/node/.npm-global
BACKUP_FILE=/opt/openclaw-backup.tar.xz

# Initialize npm global directory: extract from factory backup
# Runs as node user, no chown needed (Dockerfile pre-sets directory permissions)
# When a bind mount volume is empty on first start, restore from the image-bundled archive
if [ ! -f "${NPM_GLOBAL_DIR}/lib/node_modules/openclaw/package.json" ]; then
    echo "==> OpenClaw not found in volume, initializing from image backup..."
    tar -xJf "${BACKUP_FILE}" -C /home/node
    echo "==> Initialized. Version: $(openclaw --version 2>/dev/null || echo 'unknown')"
fi

echo "==> OpenClaw version: $(openclaw --version 2>/dev/null || echo 'unknown')"

# Execute CMD (exec ensures process replacement for proper signal handling)
exec "$@"
