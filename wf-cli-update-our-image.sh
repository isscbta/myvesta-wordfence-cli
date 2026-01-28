#!/bin/bash

set -e

echo
echo "======================================"
echo " WordFence CLI Docker update"
echo "======================================"
echo

IMAGE_REMOTE="mycityhosting/wordfence-cli:with-vectorscan-amd64"
IMAGE_LOCAL="wordfence-cli:latest"

echo "= Starting WordFence CLI update..."

# --------------------------------------------------
# 1. Stop and remove all old WordFence containers
# --------------------------------------------------
echo "= Removing old WordFence containers..."

docker ps -a --filter "ancestor=${IMAGE_LOCAL}" -q | xargs -r docker rm -f
docker ps -a --filter "ancestor=mycityhosting/wordfence-cli" -q | xargs -r docker rm -f
docker ps -a --filter "ancestor=isscbta/wordfence-cli" -q | xargs -r docker rm -f

# --------------------------------------------------
# 2. Remove old WordFence images (safe, targeted)
# --------------------------------------------------
echo "= Removing old WordFence images..."

docker rmi -f isscbta/wordfence-cli:with-vectorscan-amd64 2>/dev/null || true
docker rmi -f wordfence-cli:latest 2>/dev/null || true

# --------------------------------------------------
# 3. Pull new image
# --------------------------------------------------
echo "= Pulling new WordFence CLI image..."
docker pull "${IMAGE_REMOTE}"

# --------------------------------------------------
# 4. Retag as local latest
# --------------------------------------------------
echo "= Tagging image locally..."
docker tag "${IMAGE_REMOTE}" "${IMAGE_LOCAL}"

# --------------------------------------------------
# 5. Cleanup dangling Docker layers
# --------------------------------------------------
echo "= Cleaning dangling Docker layers..."
docker image prune -f > /dev/null 2>&1

# --------------------------------------------------
# 6. Sanity check (non-fatal)
# --------------------------------------------------
echo "= Running sanity check..."
docker run --rm "${IMAGE_LOCAL}" wordfence version || true

echo
echo "======================================"
echo " WordFence CLI update completed"
echo "======================================"
echo
