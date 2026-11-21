# Run with systemd's EnvironmentFile loaded. Never print setting values.
required = %w[SECRET_KEY_BASE APP_HOST APP_PROTOCOL MAIL_FROM SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD]
errors = required.select { |key| ENV[key].to_s.strip.empty? }.map { |key| "#{key} is required" }
errors << "RAILS_ENV must be production" unless ENV["RAILS_ENV"] == "production"
errors << "SECRET_KEY_BASE must contain at least 64 characters" if ENV.fetch("SECRET_KEY_BASE", "").length < 64
errors << "APP_PROTOCOL must be http or https" unless %w[http https].include?(ENV["APP_PROTOCOL"])
host = ENV.fetch("APP_HOST", "")
unless host.match?(/\A[a-zA-Z0-9][a-zA-Z0-9.-]*\z/) && !%w[localhost bulletin.example.edu].include?(host)
  errors << "APP_HOST must be your public hostname or IPv4 address, without a scheme, port, or path"
end
port = ENV.fetch("SMTP_PORT", "")
errors << "SMTP_PORT must be between 1 and 65535" unless port.match?(/\A\d+\z/) && (1..65535).cover?(port.to_i)
errors << "MAIL_FROM must be an email address" unless ENV.fetch("MAIL_FROM", "").match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
errors << "Replace the SMTP_PASSWORD placeholder" if ENV["SMTP_PASSWORD"] == "replace-with-google-app-password"
errors << "SOLID_QUEUE_IN_PUMA must be true for the single-server worker" unless ENV["SOLID_QUEUE_IN_PUMA"] == "true"
abort "Production configuration needs attention:\n- #{errors.uniq.join("\n- ")}" if errors.any?
puts "Production configuration validated (values hidden)."
