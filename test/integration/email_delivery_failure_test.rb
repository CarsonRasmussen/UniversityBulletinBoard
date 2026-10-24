require "test_helper"
require "net/smtp"

class EmailDeliveryFailureTest < ActionDispatch::IntegrationTest
  class RejectAuthentication
    class << self
      attr_accessor :failure
    end

    def self.delivering_email(message)
      raise failure, "Delivery failed"
    end
  end

  setup do
    RejectAuthentication.failure = Net::SMTPAuthenticationError
    ActionMailer::Base.register_interceptor(RejectAuthentication)
  end

  test "SMTP connection failures show a simple retry message" do
    user = User.create!(name: "Student", email: "retry@boisestate.edu",
      password: "a long test password", password_confirmation: "a long test password")
    [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
      Net::SMTPFatalError, OpenSSL::SSL::SSLError ].each do |failure|
      RejectAuthentication.failure = failure
      post verification_path, params: { email: user.email }
      assert_redirected_to login_path
      assert_match "could not be sent", flash[:alert]
      assert_not user.reload.verified?
    end
  end

  teardown do
    ActionMailer::Base.unregister_interceptor(RejectAuthentication)
  end

  test "failed registration email keeps the account unverified and allows retry" do
    assert_difference "User.count", 1 do
      post signup_path, params: { user: { name: "Student", email: "retry@u.boisestate.edu",
        password: "a long test password", password_confirmation: "a long test password" } }
    end
    assert_redirected_to login_path
    assert_not User.last.verified?
    assert_match "could not be sent", flash[:alert]
    assert_nil flash[:notice]

    post verification_path, params: { email: User.last.email }
    assert_redirected_to login_path
    assert_match "could not be sent", flash[:alert]
    assert_not User.last.verified?
  end
end
