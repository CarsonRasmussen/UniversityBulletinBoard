class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :saved_posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  validates :title, :description, presence: true
  validates :category, inclusion: { in: %w[Events Clubs Announcements Discussions] }
end
