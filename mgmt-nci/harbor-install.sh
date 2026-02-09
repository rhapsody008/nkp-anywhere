#!/bin/bash
set -euo pipefail

# ===================================================================
# Harbor Installation Script (Modernized)
# ===================================================================
# Downloads and installs Harbor container registry with TLS
# Prerequisites: Docker (installed by cloud-init), certificates downloaded
#
# Environment Variables:
#   REGISTRY_FQDN  - Harbor FQDN (default: registry.ntnxlab.local)
#   DOMAIN_NAME    - Domain name (default: ntnxlab.local)

# sudo REGISTRY_FQDN=zy-registry.ntnxlab.local DOMAIN_NAME=ntnxlab.local HARBOR_URL=./harbor-offline-installer-v2.14.2.tgz ./harbor-install.sh

REGISTRY_FQDN="${REGISTRY_FQDN:-registry.ntnxlab.local}"
DOMAIN_NAME="${DOMAIN_NAME:-ntnxlab.local}"
CERT_PATH="/home/nutanix/certificates/server.crt"
KEY_PATH="/home/nutanix/certificates/server.key"
CA_CHAIN_PATH="/home/nutanix/certificates/wskn-ca-chain.crt"
HARBOR_DIR="/opt/harbor"

echo "============================================"
echo "Harbor Installation"
echo "============================================"
echo "FQDN: ${REGISTRY_FQDN}"
echo "Domain: ${DOMAIN_NAME}"
echo "============================================"

# Wait for Docker to be ready (installed by cloud-init)
echo "[1/7] Waiting for Docker..."
max_attempts=60
attempt=0
until docker info >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "ERROR: Docker not available after ${max_attempts} attempts"
    exit 1
  fi
  echo "  Waiting for Docker... (attempt ${attempt}/${max_attempts})"
  sleep 5
done
echo "  Docker is ready"

# Wait for certificates (downloaded by cloud-init)
echo "[2/7] Waiting for certificates..."
attempt=0
until [ -f "$CERT_PATH" ] && [ -f "$KEY_PATH" ] && [ -f "$CA_CHAIN_PATH" ]; do
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "ERROR: Certificates not available after ${max_attempts} attempts"
    exit 1
  fi
  echo "  Waiting for certificates... (attempt ${attempt}/${max_attempts})"
  sleep 5
done
echo "  Certificates found"

# Download Harbor from internal file server
echo "[3/8] Downloading Harbor..."
mkdir -p ${HARBOR_DIR}
cd ${HARBOR_DIR}

# if [ -z "$HARBOR_URL" ]; then
#   echo "  ERROR: HARBOR_URL environment variable not set"
#   exit 1
# fi

# echo "  Harbor URL: ${HARBOR_URL}"
# echo "  Downloading..."
# wget -q --show-progress "${HARBOR_URL}"


mv /home/nutanix/harbor-offline-installer*.tgz .


echo "[4/8] Extracting Harbor..."
tar xzf harbor-offline-installer*.tgz
cd harbor

# Load Harbor Docker images
echo "[5/8] Loading Harbor Docker images (this may take several minutes)..."
docker load -i harbor.*.tar.gz

# Configure Docker to trust the CA certificate
echo "[6/8] Configuring Docker certificate trust..."
mkdir -p "/etc/docker/certs.d/${REGISTRY_FQDN}"
cp "${CA_CHAIN_PATH}" "/etc/docker/certs.d/${REGISTRY_FQDN}/ca.crt"

# Install CA system-wide
cp "${CA_CHAIN_PATH}" /usr/local/share/ca-certificates/harbor-ca.crt
update-ca-certificates

# Restart Docker to pick up certificate changes
systemctl restart docker

# Wait for Docker to be ready again
until docker info >/dev/null 2>&1; do
  sleep 2
done

# Configure Harbor
echo "[7/8] Configuring Harbor..."
cp harbor.yml.tmpl harbor.yml

# Update configuration
sed -i "s|hostname: .*|hostname: ${REGISTRY_FQDN}|" harbor.yml
sed -i "s|certificate: .*|certificate: ${CERT_PATH}|" harbor.yml
sed -i "s|private_key: .*|private_key: ${KEY_PATH}|" harbor.yml

# Install Harbor
echo "[8/8] Installing Harbor (this may take a few minutes)..."
./prepare
./install.sh

echo ""
echo "============================================"
echo "Harbor Installation Complete!"
echo "============================================"
echo "URL: https://${REGISTRY_FQDN}"
echo "Username: admin"
echo "Password: Harbor12345"
echo ""
echo "Docker login: docker login ${REGISTRY_FQDN}"
echo "============================================"
