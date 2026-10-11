#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
WORKER_IP="192.168.56.111"
TOKEN_FILE="/vagrant/.k3s-token"

IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP" '$4 ~ "^" ip "/" {print $2; exit}')

if [ -z "$IFACE" ]; then
    echo "Network interface not found"
    exit 1
fi

while [ ! -s "$TOKEN_FILE" ]; do
    echo "Waiting for K3s Server token..."
    sleep 5
done

K3S_TOKEN=$(cat "$TOKEN_FILE")

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh

K3S_URL="https://${SERVER_IP}:6443" \
K3S_TOKEN="${K3S_TOKEN}" \
INSTALL_K3S_EXEC="agent --node-ip ${WORKER_IP} --flannel-iface ${IFACE}" \
    sh /tmp/install-k3s.sh

echo "K3s Worker installation completed."