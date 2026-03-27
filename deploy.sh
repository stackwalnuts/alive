#!/bin/bash
# Deploy walnut plugin from local clone to cache + marketplace
# Usage: ./deploy.sh [--dry-run]

set -euo pipefail

SOURCE="$(cd "$(dirname "$0")/plugins/walnut" && pwd)"
CACHE="$HOME/.claude/plugins/cache/stackwalnuts/walnut/1.0.0"
MARKETPLACE="$HOME/.claude/plugins/marketplaces/stackwalnuts/plugins/walnut"

if [ ! -d "$SOURCE" ]; then
  echo "ERROR: Source not found at $SOURCE"
  exit 1
fi

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  echo "=== DRY RUN ==="
fi

echo "Source:      $SOURCE"
echo "Cache:       $CACHE"
echo "Marketplace: $MARKETPLACE"
echo ""

# Deploy to cache (if it exists)
if [ -d "$CACHE" ]; then
  rsync -av --delete \
    --exclude='.git' \
    --exclude='.DS_Store' \
    $DRY_RUN \
    "$SOURCE/" "$CACHE/"
  echo ""
  echo "Cache deployed."
else
  echo "Cache dir not found at $CACHE — skipping."
fi

# Deploy to marketplace (if it exists)
if [ -d "$MARKETPLACE" ]; then
  rsync -av --delete \
    --exclude='.git' \
    --exclude='.DS_Store' \
    $DRY_RUN \
    "$SOURCE/" "$MARKETPLACE/"
  echo ""
  echo "Marketplace deployed."
else
  echo "Marketplace dir not found at $MARKETPLACE — skipping."
fi

echo ""
echo "Done $(date '+%Y-%m-%d %H:%M:%S')"
