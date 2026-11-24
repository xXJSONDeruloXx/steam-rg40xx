#!/bin/bash
# Builds the arm64 Debian rootfs and exports it to out/rootfs.tar.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
docker build --platform linux/arm64 -t steam-rg40xx -f rootfs/Dockerfile .
id=$(docker create --platform linux/arm64 steam-rg40xx)
trap 'docker rm -f "$id" >/dev/null' EXIT
docker export "$id" -o out/rootfs.tar
ls -la out/rootfs.tar
