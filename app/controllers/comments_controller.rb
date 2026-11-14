class CommentsController < PostInteractionsController
  def create
    @comment = @post.comments.build(params.require(:comment).permit(:body))
    @comment.user = current_user
    if @comment.save
      redirect_to post_path(@post, anchor: "comments"), notice: "Comment added.", status: :see_other
    else
      render "posts/show", status: :unprocessable_entity
    end
  end
end
