class PostInteractionsController < ApplicationController
  before_action :require_student
  before_action :set_post
  rescue_from ActiveRecord::RecordNotFound, with: :post_not_found

  private

  def require_student
    redirect_to login_path, alert: "Please log in to comment, like, or save posts." unless current_user
  end

  def set_post
    @post = Post.find(params[:post_id])
  end

  def post_not_found
    render plain: "Post not found.", status: :not_found
  end
end
