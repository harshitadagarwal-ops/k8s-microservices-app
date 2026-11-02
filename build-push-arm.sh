#!/usr/bin/env bash
# Build + push multi-arch (amd64 + arm64) images so the app runs on both
# x86 and Graviton nodes. Requires docker buildx.
set -euo pipefail
REG=105673693246.dkr.ecr.us-east-1.amazonaws.com
cd "$(dirname "$0")"

# Ensure a buildx builder exists.
docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch
docker buildx inspect --bootstrap

echo ">> backend (amd64+arm64)"
docker buildx build --platform linux/amd64,linux/arm64 \
  -t "$REG/three-tier/backend:latest" --push ./backend

echo ">> frontend (amd64+arm64)"
docker buildx build --platform linux/amd64,linux/arm64 \
  -t "$REG/three-tier/frontend:latest" --push ./frontend

echo ">> DONE"
