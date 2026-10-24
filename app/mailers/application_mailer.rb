class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "no-reply@localhost") }
  layout "mailer"
end
