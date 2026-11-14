class SavedPostsController < PostInteractionsController
  def create
    current_user.saved_posts.find_or_create_by!(post: @post)
    redirect_to @post, notice: "Post saved.", status: :see_other
  end

  def destroy
    current_user.saved_posts.find_by(post: @post)&.destroy!
    redirect_to @post, notice: "Post removed from saved posts.", status: :see_other
  end
end
