require "test_helper"

class StudentAccountsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def signup(email: "student@boisestate.edu", confirmation: "a long test password")
    post signup_path, params: { user: { name: "Student", email: email,
      password: "a long test password", password_confirmation: confirmation } }
  end

  test "signup, verification, login and logout" do
    assert_difference "User.count", 1 do
      assert_emails(1) { signup }
    end
    user = User.last
    assert_not user.verified?
    assert_not_equal "a long test password", user.password_digest
    post login_path, params: { email: user.email, password: "a long test password" }
    assert_response :unprocessable_entity
    token = user.generate_token_for(:email_verification)
    get verification_path(token: token)
    assert_response :success
    assert_not user.reload.verified?
    patch verification_path, params: { token: token }
    assert user.reload.verified?
    assert_nil User.find_by_token_for(:email_verification, token)
    post login_path, params: { email: user.email.upcase, password: "a long test password" }
    assert_redirected_to root_path
    get root_path
    assert_select "button", "Log out"
    delete logout_path
    follow_redirect!
    assert_select "a", "Log in"
  end

  test "rejects non-university and lookalike domains and mismatched passwords" do
    [ "student@gmail.com", "student@boisestate.edu.evil.com", "student@u.boisestate.edu.evil.com", "student@sub.boisestate.edu" ].each do |email|
      assert_no_difference("User.count") { signup(email: email) }
      assert_response :unprocessable_entity
    end
    assert_no_difference("User.count") { signup(confirmation: "wrong") }
    assert_response :unprocessable_entity
  end

  test "accepts and verifies student subdomain email" do
    assert_difference "User.count", 1 do
      assert_emails(1) { signup(email: " Student@U.BoiseState.edu ") }
    end
    user = User.last
    assert_equal "student@u.boisestate.edu", user.email
    patch verification_path, params: { token: user.generate_token_for(:email_verification) }
    assert user.reload.verified?
    post login_path, params: { email: user.email, password: "a long test password" }
    assert_redirected_to root_path
  end

  test "normalizes emails and rejects duplicate registration" do
    signup(email: " Student@BoiseState.edu ")
    assert_equal "student@boisestate.edu", User.last.email
    assert_no_difference("User.count") { signup }
    assert_response :unprocessable_entity
  end

  test "invalid and expired verification tokens cannot verify an account" do
    signup
    token = User.last.generate_token_for(:email_verification)
    travel 25.hours do
      patch verification_path, params: { token: token }
      assert_redirected_to login_path
      assert_not User.last.verified?
    end
    patch verification_path, params: { token: "invalid" }
    assert_redirected_to login_path
  end

  test "resend sends verification for an unverified account" do
    signup
    assert_emails(1) { post verification_path, params: { email: " STUDENT@BOISESTATE.EDU " } }
    assert_redirected_to login_path
    assert_equal "Verification sent to your email.", flash[:notice]
  end

  test "resend redirects unknown accounts to signup without sending email" do
    assert_emails(0) { post verification_path, params: { email: "unknown@boisestate.edu" } }
    assert_redirected_to signup_path
    assert_equal "Please create an account first.", flash[:alert]
  end

  test "resend tells verified accounts to log in without sending email" do
    signup
    User.last.update!(verified: true)
    assert_emails(0) { post verification_path, params: { email: User.last.email } }
    assert_redirected_to login_path
    assert_equal "Your email is already verified. Please log in.", flash[:notice]
  end

  test "wrong password does not log in" do
    signup
    User.last.update!(verified: true)
    post login_path, params: { email: User.last.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Email or password is incorrect."
    get root_path
    assert_select "a", "Log in"
  end

  test "unsupported and malformed emails show a clear error across account forms" do
    [ "student@gmail.com", "student@boisestate.edu.evil.com", "student@u.boisestate.edu.evil.com",
      "student@sub.boisestate.edu", ".student@boisestate.edu", "student..name@u.boisestate.edu",
      "student@boisestate.edu\nattacker@example.com", "" ].each do |email|
      assert_no_difference("User.count") { assert_emails(0) { signup(email: email) } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"

      post login_path, params: { email: email, password: "a long test password" }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: User::UNIVERSITY_EMAIL_MESSAGE

      assert_emails(0) { post verification_path, params: { email: email } }
      assert_redirected_to login_path
      assert_equal User::UNIVERSITY_EMAIL_MESSAGE, flash[:alert]
    end
  end

  test "missing login password has a simple error" do
    post login_path, params: { email: "student@boisestate.edu", password: "" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Enter your password."
  end

  test "unverified login explains how to continue" do
    signup
    post login_path, params: { email: User.last.email, password: "a long test password" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Verify your email first/
  end
end
