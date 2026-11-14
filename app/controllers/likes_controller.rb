class LikesController < PostInteractionsController
  def create
    current_user.likes.find_or_create_by!(post: @post)
    redirect_to @post, notice: "Post liked.", status: :see_other
  end

  def destroy
    current_user.likes.find_by(post: @post)&.destroy!
    redirect_to @post, notice: "Like removed.", status: :see_other
  end
end
