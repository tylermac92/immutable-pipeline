#!/bin/bash
set -euo pipefail

GOSS_VERSION="0.4.9"
GOSS_ARCH="amd64"
GOSS_URL="https://github.com/goss-org/goss/releases/download/v${GOSS_VERSION}/goss-linux-${GOSS_ARCH}"
GOSS_DST="/usr/local/bin/goss"

echo "==> Installing Goss ${GOSS_VERSION}"
curl -fsSL "${GOSS_URL}" -o "${GOSS_DST}"
chmod +x "${GOSS_DST}"
goss --version

echo "==> Running validation spec"
goss --gossfile /tmp/goss.yaml validate --format documentation
