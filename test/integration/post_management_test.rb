require "test_helper"

class PostManagementTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @author = student("author")
    @other = student("other")
    @post = @author.posts.create!(title: "Original title", description: "Original description", category: "Events")
    @post.image.attach(io: File.open(file_fixture("campus.png")), filename: "campus.png", content_type: "image/png")
    @original_blob = @post.image.blob
  end

  def student(name)
    User.create!(name: name.capitalize, email: "#{name}@boisestate.edu", verified: true,
      password: "a long test password", password_confirmation: "a long test password")
  end

  def login_as(user)
    post login_path, params: { email: user.email, password: "a long test password" }
  end

  test "only the author sees management controls and a delete confirmation" do
    get post_path(@post)
    assert_select "a[href='#{edit_post_path(@post)}']", count: 0
    assert_select "button", text: "Delete post", count: 0
    login_as(@other)
    get post_path(@post)
    assert_select "a[href='#{edit_post_path(@post)}']", count: 0
    assert_select "button", text: "Delete post", count: 0
    login_as(@author)
    get post_path(@post)
    assert_select "a[href='#{edit_post_path(@post)}']", "Edit post"
    assert_select "form[data-turbo-confirm] button", "Delete post"
    assert_select "form input[name='_method'][value='delete']"
  end

  test "author can edit text and category without changing author creation date or image" do
    login_as(@author)
    get edit_post_path(@post)
    assert_response :success
    assert_select "input[name='post[title]'][value='Original title']"
    assert_select "textarea", "Original description"
    original_created_at = @post.created_at
    patch post_path(@post), params: { post: { title: "Updated title", description: "Updated description",
      category: "Clubs", user_id: @other.id, created_at: 1.year.ago, image: "" } }
    assert_response :see_other
    assert_redirected_to post_path(@post)
    assert_equal "Post updated.", flash[:notice]
    @post.reload
    assert_equal "Updated title", @post.title
    assert_equal "Updated description", @post.description
    assert_equal "Clubs", @post.category
    assert_equal @author.id, @post.user_id
    assert_equal original_created_at, @post.created_at
    assert_equal @original_blob.id, @post.image.blob.id
    follow_redirect!
    assert_select "h1", "Updated title"
  end

  test "another user cannot edit update or delete a post using direct requests" do
    login_as(@other)
    get edit_post_path(@post)
    assert_response :forbidden
    patch post_path(@post), params: { post: { title: "Stolen", user_id: @other.id, remove_image: "1" } }
    assert_response :forbidden
    assert_no_difference [ "Post.count", "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count" ] do
      delete post_path(@post)
    end
    assert_response :forbidden
    assert_equal "Original title", @post.reload.title
    assert_equal @author.id, @post.user_id
    assert_equal @original_blob.id, @post.image.blob.id
  end

  test "guests cannot edit update or delete" do
    get edit_post_path(@post)
    assert_redirected_to login_path
    patch post_path(@post), params: { post: { title: "Changed" } }
    assert_redirected_to login_path
    assert_no_difference("Post.count") { delete post_path(@post) }
    assert_redirected_to login_path
    assert_equal "Original title", @post.reload.title
    assert_equal @original_blob.id, @post.image.blob.id
  end

  test "an author whose verification is revoked cannot manage posts" do
    login_as(@author)
    @author.update!(verified: false)
    get edit_post_path(@post)
    assert_redirected_to login_path
    patch post_path(@post), params: { post: { title: "Changed" } }
    assert_redirected_to login_path
    assert_no_difference("Post.count") { delete post_path(@post) }
    assert_redirected_to login_path
    assert_equal "Original title", @post.reload.title
  end

  test "failed edits preserve entered text and leave saved text and image intact" do
    login_as(@author)
    patch post_path(@post), params: { post: { title: "New title", description: "", category: "Clubs", remove_image: "1" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Description is required/
    assert_select "input[name='post[title]'][value='New title']"
    assert_select "option[selected]", "Clubs"
    assert_select "input[name='post[remove_image]'][checked]"
    assert_select "img.post-edit-image"
    assert_equal "Original title", @post.reload.title
    assert_equal "Original description", @post.description
    assert_equal @original_blob.id, @post.image.blob.id
  end

  test "invalid replacement images leave the existing image unchanged" do
    login_as(@author)
    [ Rack::Test::UploadedFile.new(StringIO.new("<html>not an image</html>"), "image/png", true, original_filename: "fake.png"),
      Rack::Test::UploadedFile.new(StringIO.new(File.binread(file_fixture("campus.png")) + "x" * 5.megabytes), "image/png", true, original_filename: "large.png") ].each do |image|
      assert_no_difference [ "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count" ] do
        patch post_path(@post), params: { post: { title: "Unsaved title", image: image } }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Image must/
      assert_select "img.post-edit-image"
      assert_equal "Original title", @post.reload.title
      assert_equal @original_blob.id, @post.image.blob.id
    end
  end

  test "author can replace an image and replacement takes priority over removal" do
    login_as(@author)
    image = fixture_file_upload("campus.jpg", "image/jpeg", true)
    patch post_path(@post), params: { post: { image: image, remove_image: "1" } }
    assert_redirected_to post_path(@post)
    assert_equal "image/jpeg", @post.reload.image.blob.content_type
    assert_not_equal @original_blob.id, @post.image.blob.id
    assert_equal File.binread(file_fixture("campus.jpg")), @post.image.download
  end

  test "author can remove an image without deleting the post" do
    login_as(@author)
    assert_no_difference("Post.count") do
      patch post_path(@post), params: { post: { remove_image: "1" } }
    end
    assert_redirected_to post_path(@post)
    assert_not @post.reload.image.attached?
    assert_equal "Original title", @post.title
  end

  test "deleting a post removes dependent records and purges its uploaded image" do
    @post.comments.create!(user: @other, body: "A comment")
    @post.likes.create!(user: @other)
    @post.saved_posts.create!(user: @other)
    login_as(@author)
    assert_difference [ "Post.count", "Comment.count", "Like.count", "SavedPost.count", "ActiveStorage::Attachment.count" ], -1 do
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob) { delete post_path(@post) }
    end
    assert_response :see_other
    assert_redirected_to posts_path
    assert_equal "Post deleted.", flash[:notice]
    assert_not ActiveStorage::Blob.exists?(@original_blob.id)
    assert_not @original_blob.service.exist?(@original_blob.key)
    get post_path(@post)
    assert_response :not_found
  end

  test "missing posts return a clear not found response for all management actions" do
    login_as(@author)
    get edit_post_path(id: 0)
    assert_response :not_found
    patch post_path(id: 0), params: { post: { title: "Missing" } }
    assert_response :not_found
    delete post_path(id: 0)
    assert_response :not_found
    assert_equal "Post not found.", response.body
  end
end
