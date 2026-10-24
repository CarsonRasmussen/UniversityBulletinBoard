class RegistrationsController < ApplicationController
  rate_limit to: 5, within: 3.minutes, only: :create,
    with: -> { redirect_to signup_path, alert: "Too many attempts. Try again in 3 minutes." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:name, :email, :password, :password_confirmation))
    if @user.save
      VerificationMailer.verify(@user).deliver_now
      redirect_to login_path, notice: "Account created. Check your university inbox to verify your email, then log in."
    else
      render :new, status: :unprocessable_entity
    end
  end
end
