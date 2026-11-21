#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ruby deploy/validate-env.rb
required_ruby="$(tr -d '\r\n' < .ruby-version)"
required_ruby="${required_ruby#ruby-}"
test "$(ruby -e 'print RUBY_VERSION')" = "$required_ruby" || {
  echo "Ruby version does not match .ruby-version. Run setup-ec2.sh."; exit 1;
}
mkdir -p log tmp/pids storage
bundle config set --local path vendor/bundle
bundle config set --local frozen true
bundle install
bundle exec rails db:prepare
bundle exec rails assets:precompile
