require "test_helper"

class PostInteractionsTest < ActionDispatch::IntegrationTest
  setup do
    @student = student("interactor")
    @other = student("other")
    @post = @other.posts.create!(title: "Campus news", description: "Welcome", category: "Announcements")
  end

  def student(name)
    User.create!(name: name, email: "#{name}@boisestate.edu", verified: true,
      password: "a long test password", password_confirmation: "a long test password")
  end

  def login
    post login_path, params: { email: @student.email, password: "a long test password" }
  end

  test "guests and revoked accounts cannot interact or access personal lists" do
    2.times do |attempt|
      if attempt == 1
        login
        @student.update!(verified: false)
      end
      assert_no_difference [ "Comment.count", "Like.count", "SavedPost.count" ] do
        post post_comments_path(@post), params: { comment: { body: "Blocked" } }
        assert_redirected_to login_path
        [ post_like_path(@post), post_saved_post_path(@post) ].each do |path|
          post path
          assert_redirected_to login_path
          delete path
          assert_redirected_to login_path
        end
      end
      [ saved_posts_path, liked_posts_path ].each do |path|
        get path
        assert_redirected_to login_path
      end
    end
  end

  test "comments use logged in author and route post and escape content" do
    login
    other_post = @other.posts.create!(title: "Other", description: "Other", category: "Events")
    body = "<script>alert('x')</script>\nHello"
    assert_difference("Comment.count", 1) do
      post post_comments_path(@post), params: { comment: { body: body, user_id: @other.id, post_id: other_post.id } }
    end
    assert_redirected_to post_path(@post, anchor: "comments")
    assert_equal @student, Comment.last.user
    assert_equal @post, Comment.last.post
    follow_redirect!
    assert_select ".comment-body script", count: 0
    assert_select ".comment-body", text: /<script>/
    delete logout_path
    get post_path(@post)
    assert_select ".comment strong", @student.name
    assert_select "textarea", count: 0
  end

  test "invalid comments preserve text and return useful errors" do
    login
    [ "   ", "a" * 2001 ].each do |body|
      assert_no_difference("Comment.count") do
        post post_comments_path(@post), params: { comment: { body: body } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Body/
      assert_equal body, css_select("textarea").first.text
      assert_select ".comment", count: 0
    end
    post post_comments_path(@post), params: { comment: { body: "a" * 2000 } }
    assert_response :see_other
  end

  test "likes and saves are idempotent owned by current user and removable only for that user" do
    login
    [ [ Like, post_like_path(@post) ], [ SavedPost, post_saved_post_path(@post) ] ].each do |model, path|
      other_record = model.create!(user: @other, post: @post)
      assert_difference("#{model}.count", 1) { post path, params: { user_id: @other.id } }
      assert_response :see_other
      assert model.exists?(user: @student, post: @post)
      assert_no_difference("#{model}.count") { post path }
      get post_path(@post)
      assert_select "button", text: model == Like ? "Unlike" : "Unsave"
      assert_difference("#{model}.count", -1) { delete path, params: { user_id: @other.id, id: other_record.id } }
      assert_response :see_other
      assert model.exists?(other_record.id)
      assert_no_difference("#{model}.count") { delete path }
    end
    get post_path(@post)
    assert_select ".like-count", "1 like"
  end

  test "saved and liked collections are private and paginated" do
    login
    @other.likes.create!(post: @post)
    @other.saved_posts.create!(post: @post)
    [ [ Like, liked_posts_path, "Liked posts" ], [ SavedPost, saved_posts_path, "Saved posts" ] ].each do |model, path, title|
      get path, params: { user_id: @other.id }
      assert_response :success
      assert_select "h1", title
      assert_select ".post-card", count: 0
      13.times do |n|
        item = @student.posts.create!(title: "#{title} #{n}", description: "Campus", category: "Clubs")
        model.create!(user: @student, post: item)
      end
      get path
      assert_select ".post-card", count: 12
      assert_select ".post-card h3", text: "Campus news", count: 0
      next_link = css_select("nav.posts-pagination a").find { |a| a.text == "Next" }["href"]
      get next_link
      assert_select "h1", title
      assert_select ".post-card", count: 1
    end
  end

  test "interactions with missing posts return not found" do
    login
    post post_comments_path(post_id: 0), params: { comment: { body: "Hello" } }
    assert_response :not_found
    [ post_like_path(post_id: 0), post_saved_post_path(post_id: 0) ].each do |path|
      post path
      assert_response :not_found
      delete path
      assert_response :not_found
    end
  end
end
