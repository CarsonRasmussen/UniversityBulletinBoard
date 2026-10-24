class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to login_path, alert: "Too many attempts. Try again in 3 minutes." }

  def new
  end

  def create
    unless User.university_email?(params[:email])
      flash.now[:alert] = User::UNIVERSITY_EMAIL_MESSAGE
      return render :new, status: :unprocessable_entity
    end
    if params[:password].blank?
      flash.now[:alert] = "Enter your password."
      return render :new, status: :unprocessable_entity
    end
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    if user&.authenticate(params[:password].to_s)
      if user.verified?
        reset_session
        session[:user_id] = user.id
        redirect_to root_path, notice: "You're logged in."
      else
        flash.now[:alert] = "Verify your email first. Check your inbox or resend the verification email below."
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Email or password is incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "You're logged out.", status: :see_other
  end
end
