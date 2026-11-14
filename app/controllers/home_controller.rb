class HomeController < ApplicationController
  def index
    @posts = Post.includes(:user).with_attached_image.popular_first.limit(4)
  end
end
