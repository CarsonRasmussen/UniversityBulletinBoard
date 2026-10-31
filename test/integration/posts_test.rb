require "test_helper"

class PostsTest < ActionDispatch::IntegrationTest
  PNG = File.binread(Rails.root.join("test/fixtures/files/campus.png")).freeze

  setup do
    @student = User.create!(name: "Campus Student", email: "poster@u.boisestate.edu", verified: true,
      password: "a long test password", password_confirmation: "a long test password")
  end

  def login
    post login_path, params: { email: @student.email, password: "a long test password" }
  end

  def post_attributes
    { title: "Campus club meetup", description: "Join us in the student union.\nEveryone is welcome.", category: "Clubs" }
  end

  def upload(data: PNG, filename: "campus.png", type: "image/png")
    Rack::Test::UploadedFile.new(StringIO.new(data), type, true, original_filename: filename)
  end

  test "guests can browse empty posts but cannot create posts" do
    get posts_path
    assert_response :success
    assert_select "h3", "No posts yet"
    get new_post_path
    assert_redirected_to login_path
    assert_no_difference("Post.count") { post posts_path, params: { post: post_attributes } }
    assert_redirected_to login_path
  end

  test "verified students can create posts without images and browse their details" do
    login
    get new_post_path
    assert_response :success
    assert_select "form[enctype='multipart/form-data']"
    other_student = User.create!(name: "Other Student", email: "other@boisestate.edu", verified: true,
      password: "a long test password", password_confirmation: "a long test password")
    assert_difference("Post.count", 1) { post posts_path, params: { post: post_attributes.merge(user_id: other_student.id) } }
    campus_post = Post.last
    assert_equal @student, campus_post.user
    assert_not campus_post.image.attached?
    assert_redirected_to post_path(campus_post)
    assert_equal "Post created.", flash[:notice]
    follow_redirect!
    assert_select "h1", campus_post.title
    assert_select ".post-body", text: /Everyone is welcome/
    assert_select ".post-author", text: /Campus Student/
    assert_select ".post-author", text: /@/, count: 0
    assert_select "time[datetime='#{campus_post.created_at.iso8601}']"
    assert_select ".post-category", "Clubs"
    delete logout_path
    get post_path(campus_post)
    assert_response :success
    get posts_path
    assert_select "a[href='#{post_path(campus_post)}']", campus_post.title
    get root_path
    assert_select "a[href='#{post_path(campus_post)}']", campus_post.title
  end

  test "unverified accounts and revoked verification cannot publish" do
    @student.update!(verified: false)
    login
    assert_no_difference("Post.count") { post posts_path, params: { post: post_attributes } }
    assert_redirected_to login_path
    @student.update!(verified: true)
    login
    @student.update!(verified: false)
    assert_no_difference("Post.count") { post posts_path, params: { post: post_attributes } }
    assert_redirected_to login_path
  end

  test "uploaded image persists and is retrievable" do
    login
    assert_difference("ActiveStorage::Attachment.count", 1) do
      post posts_path, params: { post: post_attributes.merge(image: upload) }
    end
    campus_post = Post.last
    assert campus_post.reload.image.attached?
    assert_equal "image/png", campus_post.image.blob.content_type
    assert_equal PNG, campus_post.image.download
    delete logout_path
    get post_path(campus_post)
    assert_select "img.post-detail-image" do |images|
      get images.first["src"]
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_equal PNG.b, response.body.b
    end
  end

  test "missing fields and invalid categories show errors and preserve input" do
    login
    [ { title: "   " }, { description: "   " }, { category: "" }, { category: "Other" },
      { title: "x" * 151 }, { description: "x" * 10_001 } ].each do |invalid|
      assert_no_difference("Post.count") do
        post posts_path, params: { post: post_attributes.merge(invalid) }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert] li"
      if invalid.key?(:description)
        assert_select "input[name='post[title]'][value='Campus club meetup']"
      else
        assert_select "textarea", text: /Join us/
      end
    end
  end

  test "each supported category can be published" do
    login
    Post::CATEGORIES.each do |category|
      assert_difference("Post.count", 1) do
        post posts_path, params: { post: post_attributes.merge(category: category) }
      end
      assert_redirected_to post_path(Post.last)
      assert_equal category, Post.last.category
    end
  end

  test "JPEG PNG and WebP are accepted based on uploaded contents" do
    login
    { "jpg" => "image/jpeg", "png" => "image/png", "webp" => "image/webp" }.each do |extension, content_type|
      image = fixture_file_upload("campus.#{extension}", content_type)
      assert_difference("Post.count", 1) { post posts_path, params: { post: post_attributes.merge(image: image) } }
      assert_redirected_to post_path(Post.last)
      assert_equal content_type, Post.last.image.blob.content_type
    end
  end

  test "an image exactly 5 MB is accepted" do
    login
    data = PNG + "x" * (5.megabytes - PNG.bytesize)
    assert_difference("Post.count", 1) do
      post posts_path, params: { post: post_attributes.merge(image: upload(data: data)) }
    end
    assert_equal 5.megabytes, Post.last.image.blob.byte_size
  end

  test "nonimages disguised as images and oversized images are rejected" do
    login
    [ upload(data: "<html>not an image</html>", filename: "fake.png"),
      upload(data: '<svg xmlns="http://www.w3.org/2000/svg"></svg>', filename: "picture.svg", type: "image/svg+xml"),
      upload(data: PNG + "x" * 5.megabytes) ].each do |image|
      assert_no_difference [ "Post.count", "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count" ] do
        post posts_path, params: { post: post_attributes.merge(image: image) }
      end
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /Image must/
    end
  end

  test "post content is escaped and missing posts show not found" do
    campus_post = @student.posts.create!(post_attributes.merge(title: "<script>alert(1)</script>", description: "<script>alert(2)</script>"))
    get post_path(campus_post)
    assert_response :success
    assert_select "script", text: /alert\([12]\)/, count: 0
    assert_select "h1", text: "<script>alert(1)</script>"
    get post_path(id: 0)
    assert_response :not_found
    assert_equal "Post not found.", response.body
  end

  test "posts are paginated newest first" do
    13.times { |i| @student.posts.create!(post_attributes.merge(title: "Post #{i}")) }
    get posts_path
    assert_select ".post-card", count: 12
    assert_select ".post-card h3", text: "Post 12"
    assert_select "a", text: "Next"
    get posts_path(page: 2)
    assert_select ".post-card", count: 1
    assert_select ".post-card h3", text: "Post 0"
    assert_select "a", text: "Previous"
    get root_path
    assert_select ".post-card", count: 4
  end

  test "homepage and navigation link to posts and keep later features disabled" do
    get root_path
    assert_select "h2", "Latest on campus"
    assert_select "a[href='#{posts_path}']", text: /View all posts/
    assert_select "a[href='#{posts_path}']", text: "Posts"
    assert_select "a[href='#{new_post_path}']", text: "Create Post"
    assert_select "input[type=search][disabled]"
    assert_select ".category-tabs button[disabled]", count: 4
  end
end
