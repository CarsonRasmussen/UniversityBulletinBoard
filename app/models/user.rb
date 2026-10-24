class User < ApplicationRecord
  UNIVERSITY_EMAIL_PATTERN = /\A[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+(?:\.[a-z0-9!\#$%&'*+\/=?^_`{|}~-]+)*@(?:u\.)?boisestate\.edu\z/i
  UNIVERSITY_EMAIL_MESSAGE = "Please use student email."

  def self.university_email?(email)
    UNIVERSITY_EMAIL_PATTERN.match?(email.to_s.strip)
  end

  has_secure_password
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :name, with: ->(name) { name.strip }
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :saved_posts, dependent: :destroy
  has_many :likes, dependent: :destroy

  validates :name, presence: { message: "is required." }, length: { maximum: 100 }
  validates :email, presence: { message: "is required." },
    uniqueness: { message: "is already registered. Log in instead." }
  validates :email, format: { with: UNIVERSITY_EMAIL_PATTERN,
    message: UNIVERSITY_EMAIL_MESSAGE }, allow_blank: true
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :password_confirmation, presence: true, if: -> { password.present? }

  generates_token_for :email_verification, expires_in: 24.hours do
    verified
  end
end
