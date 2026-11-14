class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post
  normalizes :body, with: ->(body) { body.strip }
  validates :body, presence: { message: "is required." }, length: { maximum: 2000 }
end
