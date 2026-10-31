class PostsController < ApplicationController
  before_action :require_verified_student, only: [ :new, :create ]

  def index
    @page = [ params[:page].to_i, 1 ].max
    @posts = Post.includes(:user).with_attached_image.newest_first.offset((@page - 1) * 12).limit(13).to_a
    @next_page = @posts.length > 12
    @posts = @posts.first(12)
  end

  def show
    @post = Post.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render plain: "Post not found.", status: :not_found
  end

  def new
    @post = Post.new
  end

  def create
    @post = current_user.posts.build(params.require(:post).permit(:title, :description, :category, :image))
    if @post.save
      redirect_to @post, notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_verified_student
    redirect_to login_path, alert: "Please log in to create a post." unless current_user
  end
end
