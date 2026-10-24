require "net/smtp"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user
  rescue_from Net::SMTPError, Timeout::Error, SocketError, Errno::ECONNREFUSED,
    Errno::ECONNRESET, OpenSSL::SSL::SSLError, with: :email_delivery_failed

  private

  def email_delivery_failed(error)
    Rails.logger.error("Verification email failed: #{error.class}")
    redirect_to login_path, alert: "Verification email could not be sent. Your account is still unverified. Please try resending later."
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id], verified: true)
  end
end
