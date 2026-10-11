#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
TOKEN_FILE="/vagrant/.k3s-token"

IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$4 ~ "^" ip "/" {print $2; exit}')

if [ -z "$IFACE" ]; then
    echo "Network interface not found"
    exit 1
fi

echo "Installing K3s Server..."

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh

INSTALL_K3S_EXEC="server \
    --node-ip ${SERVER_IP} \
    --advertise-address ${SERVER_IP} \
    --flannel-iface ${IFACE}" \
    sh /tmp/install-k3s.sh

echo "Waiting for K3s token..."

until [ -s /var/lib/rancher/k3s/server/node-token ]; do
    sleep 2
done

echo "Exporting K3s token..."

cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "K3s Server installation completed."