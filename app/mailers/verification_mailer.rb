class VerificationMailer < ApplicationMailer
  def verify(user)
    @user = user
    @verification_url = verification_url(token: user.generate_token_for(:email_verification))
    mail to: user.email, subject: "Verify your University Bulletin Board account"
  end
end
