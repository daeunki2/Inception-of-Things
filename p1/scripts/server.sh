
#!/bin/bash
set -euo pipefail

SERVER_IP="192.168.56.110"
TOKEN_FILE="/vagrant/.k3s-token"

echo "Installing K3s Server..."

curl -sfL https://get.k3s.io -o /tmp/install-k3s.sh

INSTALL_K3S_EXEC="server \
	--node-ip ${SERVER_IP} \
	--advertise-address ${SERVER_IP} \
	--flannel-iface enp0s8" \
	sh /tmp/install-k3s.sh

echo "Waiting for K3s Server to be ready..."

until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "Exporting K3s token..."

cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "K3s Server installation completed."
