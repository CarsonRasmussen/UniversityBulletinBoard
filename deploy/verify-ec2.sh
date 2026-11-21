#!/usr/bin/env bash
set -euo pipefail
# Read-only checks: safe to run after deployment and again after a reboot.
BOOT_ID="$(cat /proc/sys/kernel/random/boot_id)"
if [ "${1:-}" = "$BOOT_ID" ]; then
  echo "Boot ID has not changed; reboot has not been verified."
  exit 1
fi
systemctl is-enabled --quiet bulletin-board
systemctl is-enabled --quiet nginx
systemctl is-active --quiet nginx
for attempt in {1..30}; do
  if systemctl is-active --quiet bulletin-board &&
      curl --fail --silent --max-time 5 http://127.0.0.1:3000/up >/dev/null; then
    echo "Rails is healthy; Rails and nginx are enabled at boot."
    echo "Boot ID: $BOOT_ID"
    echo "Now check the public site, email, uploads, and background jobs."
    exit 0
  fi
  sleep 2
done
echo "Rails health check failed. Inspect journalctl -u bulletin-board."
exit 1
