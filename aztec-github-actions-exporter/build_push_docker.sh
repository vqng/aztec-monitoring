#!/usr/bin/env bash
set -euo pipefail

# requires docker hub login
DOCKER_IMAGE_FULL_TAG="hvquang/aztec-gh-exporter:0.1.0"

cd $(dirname $0)
docker build -t "${DOCKER_IMAGE_FULL_TAG}" .
docker push "${DOCKER_IMAGE_FULL_TAG}"

