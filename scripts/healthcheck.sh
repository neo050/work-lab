#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$SCRIPT_DIR/../logs/healthcheck.log"
DATE="$(date '+%Y-%m-%d %H:%M:%S')"

APP_OK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health || echo "000")
DB_OK=$(docker exec pg-lab pg_isready -U postgres >/dev/null 2>&1 && echo "OK" || echo "DOWN")

echo "[$DATE] APP:$APP_OK DB:$DB_OK" | tee -a "$LOG"
