class VerificationsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path, alert: "Too many attempts. Try again in 3 minutes." }

  def show
    @token = params[:token]
    unless User.find_by_token_for(:email_verification, @token)
      redirect_to login_path, alert: "This link no longer works. Resend the verification email below."
    end
  end

  def update
    user = User.find_by_token_for(:email_verification, params[:token])
    if user
      user.update!(verified: true)
      redirect_to login_path, notice: "Email verified. You can now log in."
    else
      redirect_to login_path, alert: "This link no longer works. Resend the verification email below."
    end
  end

  def create
    unless User.university_email?(params[:email])
      return redirect_to login_path, alert: User::UNIVERSITY_EMAIL_MESSAGE
    end
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user.nil?
      redirect_to signup_path, alert: "Please create an account first."
    elsif user.verified?
      redirect_to login_path, notice: "Your email is already verified. Please log in."
    else
      VerificationMailer.verify(user).deliver_now
      redirect_to login_path, notice: "Verification sent to your email."
    end
  end
end
