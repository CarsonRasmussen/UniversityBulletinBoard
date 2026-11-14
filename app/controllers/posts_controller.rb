class PostsController < ApplicationController
  before_action :require_verified_student, except: [ :index, :show ]
  before_action :set_post, only: [ :show, :edit, :update, :destroy ]
  before_action :require_post_author, only: [ :edit, :update, :destroy ]
  rescue_from ActiveRecord::RecordNotFound, with: :post_not_found

  def index
    @query = params[:q].to_s.strip.first(200)
    @category = params[:category].to_s
    scope = Post.search(@query)
    scope = scope.where(category: @category) if @category.present?
    paginate_posts(scope)
  end

  def saved
    @collection_title = "Saved posts"
    paginate_posts(Post.where(id: current_user.saved_posts.select(:post_id)))
    render :index
  end

  def liked
    @collection_title = "Liked posts"
    paginate_posts(Post.where(id: current_user.likes.select(:post_id)))
    render :index
  end

  def show
    @comment = Comment.new
  end

  def new
    @post = Post.new
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attributes = post_params
    # Browsers submit an empty file field when no replacement is selected.
    attributes.delete(:image) if attributes[:image].blank?
    if ActiveModel::Type::Boolean.new.cast(params[:post][:remove_image]) && !attributes.key?(:image)
      @post.image = nil
    end

    if @post.update(attributes)
      redirect_to @post, notice: "Post updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy!
    redirect_to posts_path, notice: "Post deleted.", status: :see_other
  end

  private

  def paginate_posts(scope)
    @page = params[:page].to_i.clamp(1, 1_000_000)
    @posts = scope.includes(:user).with_attached_image.newest_first.offset((@page - 1) * 12).limit(13).to_a
    @next_page = @posts.length > 12
    @posts = @posts.first(12)
  end

  def require_verified_student
    return if current_user

    message = if %w[saved liked].include?(action_name)
      "Please log in to view your saved and liked posts."
    elsif %w[new create].include?(action_name)
      "Please log in to create a post."
    else
      "Please log in to edit or delete posts."
    end
    redirect_to login_path, alert: message
  end

  def set_post
    @post = Post.find(params[:id])
    @existing_image = @post.image.blob if @post.image.attached?
  end

  def require_post_author
    unless @post.user_id == current_user.id
      render plain: "You can only edit or delete your own posts.", status: :forbidden
    end
  end

  def post_params
    params.require(:post).permit(:title, :description, :category, :image)
  end

  def post_not_found
    render plain: "Post not found.", status: :not_found
  end
end
