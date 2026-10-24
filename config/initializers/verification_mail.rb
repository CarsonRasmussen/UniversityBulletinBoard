# SMTP is opt-in locally; tests always retain their isolated test delivery method.
Rails.application.configure do
  if Rails.env.development?
    config.action_mailer.default_url_options = {
      host: ENV.fetch("APP_HOST", "localhost"),
      port: ENV.fetch("APP_PORT", "3000").to_i,
      protocol: "http"
    }
    unless ENV["SMTP_ADDRESS"].present?
      config.action_mailer.delivery_method = :file
      config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
    end
  end

  if Rails.env.production? || (Rails.env.development? && ENV["SMTP_ADDRESS"].present?)
    %w[MAIL_FROM SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD].each do |key|
      raise "#{key} must be configured for SMTP delivery" if ENV[key].blank?
    end
    config.action_mailer.default_options = { from: ENV.fetch("MAIL_FROM") }
    if Rails.env.production?
      config.action_mailer.default_url_options = {
        host: ENV.fetch("APP_HOST"), protocol: ENV.fetch("APP_PROTOCOL", "https")
      }
    end
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"), port: ENV.fetch("SMTP_PORT", "587").to_i,
      user_name: ENV.fetch("SMTP_USERNAME"), password: ENV.fetch("SMTP_PASSWORD"),
      authentication: :plain, enable_starttls: true,
      open_timeout: 10, read_timeout: 10
    }
  end
end
