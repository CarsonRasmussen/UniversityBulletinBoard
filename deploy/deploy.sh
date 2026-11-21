#!/usr/bin/env bash
set -euo pipefail

HOST=""
KEY=""

while getopts "h:i:" option; do
  case "$option" in
    h) HOST="$OPTARG" ;;
    i) KEY="$OPTARG" ;;
    *) exit 1 ;;
  esac
done

if [ -z "$HOST" ] || [ -z "$KEY" ]; then
  echo "Usage: ./deploy/deploy.sh -h PUBLIC-IP -i /path/to/key.pem"
  exit 1
fi

if [[ ! "$HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Host must be an IPv4 address or DNS hostname, without a scheme or port."
  exit 1
fi

if [ ! -f "$KEY" ]; then
  echo "Key file not found: $KEY"
  exit 1
fi

for tool in ruby bundle ssh scp tar curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool"
    exit 1
  fi
done

KEY="$(cd "$(dirname "$KEY")" && pwd)/$(basename "$KEY")"
cd "$(dirname "$0")/.."

echo "Installing dependencies and running tests..."
bundle install
RAILS_ENV=test bundle exec rails db:prepare
RAILS_ENV=test PARALLEL_WORKERS=1 bundle exec rails test

echo "Packaging code..."
ARCHIVE="$(mktemp /tmp/bulletin-board.XXXXXX.tar.gz)"
trap 'rm -f "$ARCHIVE"' EXIT

bash deploy/package.sh "$ARCHIVE"

echo "Copying code to EC2..."
scp -i "$KEY" "$ARCHIVE" "ubuntu@$HOST:bulletin-board.tar.gz"

ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -i "$KEY" "ubuntu@$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
APP=/var/www/university-bulletin-board
ARCHIVE="$HOME/bulletin-board.tar.gz"
# Serialize updates on this server, including backup and preparation.
exec 9>"$HOME/.bulletin-board-deploy.lock"
flock -n 9 || { echo "Another deployment is running."; exit 1; }
test -d "$APP" || { echo "Run setup-ec2.sh first."; exit 1; }
sudo test -f /etc/bulletin-board.env
# Check archive readability before taking the application offline.
tar -tzf "$ARCHIVE" >/dev/null
WAS_ACTIVE=false
if sudo systemctl is-active --quiet bulletin-board; then WAS_ACTIVE=true; fi
MUTATED=false
BACKUP=""
recover() {
  status=$?
  if [ "$status" -ne 0 ]; then
    if [ "$MUTATED" = false ] && [ "$WAS_ACTIVE" = true ]; then
      sudo systemctl start bulletin-board || true
    elif [ "$MUTATED" = true ]; then
      sudo systemctl stop bulletin-board || true
    fi
    echo "Deployment failed. Backup: ${BACKUP:-not created}."
    echo "After code/migration changes the app stays stopped; follow README recovery steps."
    echo "Inspect: sudo journalctl -u bulletin-board-prepare -u bulletin-board -n 50 --no-pager"
  fi
}
trap recover EXIT
sudo systemctl stop bulletin-board
sudo install -d -m 700 /var/backups/bulletin-board
BACKUP="/var/backups/bulletin-board/app-$(date -u +%Y%m%d-%H%M%S)-$$.tar.gz"
# A stopped service gives SQLite databases and uploads a consistent backup.
sudo tar -czf "$BACKUP" --exclude='./vendor/bundle' --exclude='./.bundle' \
  --exclude='./tmp' --exclude='./log' --exclude='./.git' -C "$APP" .
sudo chmod 600 "$BACKUP"
MUTATED=true
tar -xzf "$ARCHIVE" -C "$APP"
rm "$ARCHIVE"
cd "$APP"
sudo bash deploy/configure-ec2.sh
# Both preparation and runtime read the same root-owned EnvironmentFile.
# No secrets are interpolated into SSH commands or sourced as shell code.
sudo systemctl start bulletin-board-prepare
sudo systemctl reset-failed bulletin-board
sudo systemctl start bulletin-board
bash deploy/verify-ec2.sh
echo "Backup retained at $BACKUP"
REMOTE

echo "Checking the live app..."
for attempt in {1..12}; do
  if curl --fail --silent --location --max-time 5 \
    "http://$HOST/up" >/dev/null; then
    echo "Deployment successful: http://$HOST/"
    exit 0
  fi
  sleep 5
done

echo "Health check failed. Check the server with:"
echo "sudo journalctl -u bulletin-board -n 50 --no-pager"
exit 1
