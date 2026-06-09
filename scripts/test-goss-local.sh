#!/bin/bash
set -euo pipefail

CONTAINER_NAME="ansible-test"
GOSS_VERSION="0.4.9"

# Detect container architecture and map to Goss release name
ARCH=$(docker exec ${CONTAINER_NAME} uname -m)
case ${ARCH} in
  x86_64)  GOSS_ARCH="amd64" ;;
  aarch64) GOSS_ARCH="arm64" ;;
  *)       echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

echo "==> Container architecture: ${ARCH} (goss binary: ${GOSS_ARCH})"
echo "==> Copying Goss spec to container"
docker cp validation/goss.yaml ${CONTAINER_NAME}:/tmp/goss.yaml

echo "==> Installing and running Goss in container"
docker exec ${CONTAINER_NAME} bash -c "
  curl -fsSL https://github.com/goss-org/goss/releases/download/v${GOSS_VERSION}/goss-linux-${GOSS_ARCH} \
    -o /usr/local/bin/goss && \
  chmod +x /usr/local/bin/goss && \
  goss --gossfile /tmp/goss.yaml validate --format documentation
"
