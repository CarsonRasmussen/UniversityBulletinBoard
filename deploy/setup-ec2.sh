#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run this on EC2 with: sudo bash deploy/setup-ec2.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH="/usr/local/bin:/usr/bin:/bin"
export DEBIAN_FRONTEND=noninteractive
id ubuntu >/dev/null 2>&1 || { echo "This installer requires the Ubuntu EC2 user 'ubuntu'."; exit 1; }

echo "Installing server tools..."
apt-get update
apt-get install -y \
  build-essential curl ca-certificates git rsync nginx \
  libssl-dev libyaml-dev zlib1g-dev libreadline-dev \
  libffi-dev libgmp-dev libsqlite3-dev sqlite3 \
  libvips-dev pkg-config openssl

if [ "$(/usr/local/bin/ruby -e 'print RUBY_VERSION' 2>/dev/null || true)" != "4.0.2" ]; then
  echo "Building Ruby 4.0.2. This may take a while..."
  mkdir -p /usr/local/src
  cd /usr/local/src

  curl -fL --retry 3 \
    https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.2.tar.gz \
    -o ruby-4.0.2.tar.gz

  # https://www.ruby-lang.org/en/news/2026/03/16/ruby-4-0-2-released/
  echo "4618db85bb9ec04d8152d0099db488694a3d3c4f52106625e4ad547f1318db87  ruby-4.0.2.tar.gz" \
    | sha256sum -c -

  tar -xzf ruby-4.0.2.tar.gz
  cd ruby-4.0.2
  ./configure --prefix=/usr/local --disable-install-doc
  make -j1
  make install
fi

gem install bundler -v 4.0.6 --no-document

echo "Creating app directory..."
install -d -o ubuntu -g ubuntu /var/www/university-bulletin-board

echo "Creating production environment file..."
if [ ! -f /etc/bulletin-board.env ]; then
  (
    umask 077
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" \
      > /etc/bulletin-board.env
  )
fi

bash "$SCRIPT_DIR/configure-ec2.sh"

echo "Server setup complete. Fill in /etc/bulletin-board.env using the example, then deploy."
