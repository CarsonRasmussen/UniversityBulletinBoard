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
PARALLEL_WORKERS=1 bundle exec rails test

echo "Packaging code..."
ARCHIVE="$(mktemp /tmp/bulletin-board.XXXXXX.tar.gz)"
trap 'rm -f "$ARCHIVE"' EXIT

tar -czf "$ARCHIVE" \
  --exclude='./.git' \
  --exclude='./.env*' \
  --exclude='*.pem' \
  --exclude='./config/master.key' \
  --exclude='./config/credentials/*.key' \
  --exclude='./.kamal' \
  --exclude='./.bundle' \
  --exclude='./vendor/bundle' \
  --exclude='./log' \
  --exclude='./tmp' \
  --exclude='./storage' \
  --exclude='./public/assets' \
  .

echo "Copying code to EC2..."
scp -i "$KEY" "$ARCHIVE" "ubuntu@$HOST:bulletin-board.tar.gz"

ssh -i "$KEY" "ubuntu@$HOST" \
  'tar -xzf "$HOME/bulletin-board.tar.gz" -C /var/www/university-bulletin-board && rm "$HOME/bulletin-board.tar.gz"'

echo "Preparing and restarting the app..."
ssh -i "$KEY" "ubuntu@$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin"
export RAILS_ENV=production
export SECRET_KEY_BASE="$(sudo sed -n 's/^SECRET_KEY_BASE=//p' /etc/bulletin-board.env)"
test -n "$SECRET_KEY_BASE"

cd /var/www/university-bulletin-board
mkdir -p log tmp/pids storage

bundle config set --local path vendor/bundle
bundle install
bundle exec rails db:prepare
bundle exec rails assets:precompile

sudo systemctl restart bulletin-board
REMOTE

echo "Checking the live app..."
for attempt in {1..12}; do
  if curl --fail --silent --max-time 5 \
    "http://$HOST/up" >/dev/null; then
    echo "Deployment successful: http://$HOST/"
    exit 0
  fi
  sleep 5
done

echo "Health check failed. Check the server with:"
echo "sudo journalctl -u bulletin-board -n 50 --no-pager"
exit 1