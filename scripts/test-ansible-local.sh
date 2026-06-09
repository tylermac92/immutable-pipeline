#!/bin/bash
set -euo pipefail

CONTAINER_NAME="ansible-test"

echo "==> Cleaning up any existing test container"
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

echo "==> Starting Ubuntu 24.04 test container"
docker run -d \
  --name ${CONTAINER_NAME} \
  --privileged \
  ubuntu:24.04 \
  sleep infinity

echo "==> Bootstrapping Python and sudo"
docker exec ${CONTAINER_NAME} bash -c "
  DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 sudo curl openssh-server && \
  useradd -m -s /bin/bash packer && \
  echo 'packer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/packer
"

echo "==> Creating dynamic inventory"
cat > /tmp/docker-inventory.ini << INVENTORY
[all]
${CONTAINER_NAME} ansible_connection=docker ansible_user=packer
INVENTORY

echo "==> Running playbook"
ANSIBLE_ROLES_PATH=./ansible/roles \
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook \
  -i /tmp/docker-inventory.ini \
  --become \
  ansible/playbook.yml

echo "==> Done. Container left running for inspection."
echo "    Exec in : docker exec -it ${CONTAINER_NAME} bash"
echo "    Clean up: docker rm -f ${CONTAINER_NAME}"
