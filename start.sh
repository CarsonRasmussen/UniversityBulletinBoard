#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

if ! command -v ruby >/dev/null 2>&1; then
  echo "Missing Ruby. Install the version listed in .ruby-version."
  exit 1
fi

if ! command -v bundle >/dev/null 2>&1; then
  echo "Missing Bundler. Run: gem install bundler"
  exit 1
fi

required_ruby="$(tr -d '\r\n' < .ruby-version)"
required_ruby="${required_ruby#ruby-}"

if [ "$(ruby -e 'print RUBY_VERSION')" != "$required_ruby" ]; then
  echo "Please install Ruby $required_ruby (see .ruby-version)."
  exit 1
fi

echo "Installing dependencies..."
bundle install

echo "Preparing database..."
bundle exec rails db:prepare

echo "Open http://localhost:3000"
exec bundle exec rails server -b 127.0.0.1 -p 3000