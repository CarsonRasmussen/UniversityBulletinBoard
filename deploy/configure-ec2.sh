#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run on EC2 with: sudo bash deploy/configure-ec2.sh"
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
test -f /etc/bulletin-board.env || { echo "Run setup-ec2.sh first."; exit 1; }
chown root:root /etc/bulletin-board.env
chmod 600 /etc/bulletin-board.env
install -d -o ubuntu -g ubuntu /var/www/university-bulletin-board
for unit in bulletin-board.service bulletin-board-prepare.service; do
  install -m 644 "$SCRIPT_DIR/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable bulletin-board nginx

# Existing nginx/HTTPS settings belong to the server administrator.
if [ ! -e /etc/nginx/sites-available/bulletin-board ]; then
  install -m 644 "$SCRIPT_DIR/nginx-bulletin-board.conf" /etc/nginx/sites-available/bulletin-board
  rm -f /etc/nginx/sites-enabled/default
fi
if [ ! -e /etc/nginx/sites-enabled/bulletin-board ] && [ ! -L /etc/nginx/sites-enabled/bulletin-board ]; then
  ln -s /etc/nginx/sites-available/bulletin-board /etc/nginx/sites-enabled/bulletin-board
fi
nginx -t
systemctl start nginx
systemctl reload nginx
echo "Services enabled for boot. Existing nginx and email settings preserved."
