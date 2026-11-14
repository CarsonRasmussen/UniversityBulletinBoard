class Post < ApplicationRecord
  CATEGORIES = %w[Events Clubs Announcements Discussions].freeze
  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :user
  has_one_attached :image
  has_many :comments, dependent: :destroy
  has_many :saved_posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  normalizes :title, :description, with: ->(value) { value.strip }
  validates :title, :description, presence: { message: "is required." }
  validates :title, length: { maximum: 150 }
  validates :description, length: { maximum: 10_000 }
  validates :category, inclusion: { in: CATEGORIES, message: "must be selected." }
  validate :acceptable_image

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :popular_first, -> {
    order(Arel.sql("(SELECT COUNT(*) FROM likes WHERE likes.post_id = posts.id) DESC"), created_at: :desc, id: :desc)
  }

  def self.search(query)
    return all if query.blank?

    pattern = "%#{sanitize_sql_like(query)}%"
    where("posts.title LIKE ? ESCAPE '\\' OR posts.description LIKE ? ESCAPE '\\'", pattern, pattern)
  end

  private

  def acceptable_image
    return unless image.attached?

    errors.add(:image, "must be a JPG, PNG, or WebP file.") unless IMAGE_TYPES.include?(image.blob.content_type)
    errors.add(:image, "must be 5 MB or smaller.") if image.blob.byte_size > 5.megabytes
  end
end
