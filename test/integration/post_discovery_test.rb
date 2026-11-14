require "test_helper"

class PostDiscoveryTest < ActionDispatch::IntegrationTest
  setup do
    @student = User.create!(name: "Student", email: "discovery@boisestate.edu", verified: true,
      password: "a long test password", password_confirmation: "a long test password")
    @event = @student.posts.create!(title: "Campus concert", description: "Music outdoors", category: "Events")
    @club = @student.posts.create!(title: "Music club", description: "Weekly campus meetings", category: "Clubs")
  end

  test "public search matches titles and descriptions with combined category filters" do
    get posts_path, params: { q: "  CONCERT  " }
    assert_response :success
    assert_select ".post-card h3", text: "Campus concert"
    assert_select ".post-card", count: 1
    get posts_path, params: { q: "outdoors" }
    assert_select ".post-card h3", text: "Campus concert"
    get posts_path, params: { q: "campus", category: "Clubs" }
    assert_select ".post-card h3", text: "Music club"
    assert_select ".post-card", count: 1
    assert_select "input[name=q][value=campus]"
    assert_select "a.category-tab.selected", "Clubs"
    get posts_path, params: { category: "Events" }
    assert_select ".post-card", count: 1
    get posts_path, params: { q: "   " }
    assert_select ".post-card", count: 2
  end

  test "literal wildcards injection attempts and unknown categories do not return unrelated posts" do
    [ { q: "%" }, { q: "_" }, { q: "' OR 1=1 --" }, { category: "Invalid" }, { q: "missing" } ].each do |query|
      get posts_path, params: query
      assert_response :success
      assert_select ".post-card", count: 0
      assert_select "h3", "No matching posts"
    end
    @club.update!(title: "100%_club")
    get posts_path, params: { q: "%_" }
    assert_select ".post-card h3", "100%_club"
  end

  test "filtered pagination preserves search category and newest order" do
    @club.update!(description: "Weekly campus gatherings")
    13.times { |n| @student.posts.create!(title: "Meeting #{n}", description: "Campus", category: "Clubs") }
    get posts_path, params: { q: "Meeting", category: "Clubs" }
    assert_select ".post-card", count: 12
    assert_select ".post-card h3 a", text: "Meeting 12"
    next_link = css_select("nav.posts-pagination a").find { |a| a.text == "Next" }["href"]
    get next_link
    assert_response :success
    assert_select ".post-card", count: 1
    assert_select ".post-card h3", "Meeting 0"
    assert_select "input[name=q][value=Meeting]"
    assert_select "a.category-tab.selected", "Clubs"
  end

  test "homepage ranks by actual likes with newest first for ties" do
    @event.likes.create!(user: @student)
    get root_path
    assert_select "h2", "Popular on campus"
    assert_equal [ "Campus concert", "Music club" ], css_select(".post-card h3").map(&:text)
    @club.likes.create!(user: @student)
    get root_path
    assert_equal [ "Music club", "Campus concert" ], css_select(".post-card h3").map(&:text)
    @club.likes.destroy_all
    get root_path
    assert_equal "Campus concert", css_select(".post-card h3").first.text
    assert_select "form[action='#{posts_path}'] input[type=search]"
  end
end
