class HomeController < ApplicationController
  def index
    @posts = Post.includes(:user).with_attached_image.newest_first.limit(4)
  end
end
