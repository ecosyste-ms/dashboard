require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    @other_user = create(:user)
    @collection = create(:collection, :public, user: @user)
    @private_collection = create(:collection, :private, user: @user)
  end

  # Authentication tests
  test "should redirect to login when not authenticated" do
    get collections_url
    assert_response :redirect
    assert_redirected_to login_url
  end

  test "should redirect to login for new collection when not authenticated" do
    get new_collection_url
    assert_response :redirect
    assert_redirected_to login_url
  end

  # Collection visibility tests
  test "should find collection by uuid" do
    # Test that collections can be found by their UUID parameter
    assert_equal @collection, Collection.find_by_uuid(@collection.uuid)
  end

  # Collection factory tests
  test "collection factory should create valid collections" do
    collection = create(:collection, user: @user)
    assert collection.valid?
    assert_equal @user, collection.user
    assert collection.github_organization_url.present?
  end

  test "collection with different traits should have correct attributes" do
    github_collection = create(:collection, :with_github_org, user: @user)
    assert github_collection.github_organization_url.present?
    
    collective_collection = create(:collection, :with_collective, user: @user)
    assert collective_collection.collective_url.present?
    
    repo_collection = create(:collection, :with_repo, user: @user)
    assert repo_collection.github_repo_url.present?
    
    private_collection = create(:collection, :private, user: @user)
    assert_equal "private", private_collection.visibility
  end

  # Collection validation tests
  test "collection should require at least one import source" do
    collection = build(:collection, 
      github_organization_url: nil,
      collective_url: nil,
      github_repo_url: nil,
      dependency_file: nil,
      user: @user
    )
    assert_not collection.valid?
    assert_includes collection.errors[:base], "You must provide a source: GitHub org, Open Collective URL, repo URL, or dependency file."
  end

  test "collection should validate GitHub organization URL format" do
    collection = build(:collection, github_organization_url: "invalid-url", user: @user)
    assert_not collection.valid?
    assert_includes collection.errors[:github_organization_url], "must be a valid GitHub organization URL"
  end

  test "collection should validate collective URL format" do
    collection = build(:collection, 
      github_organization_url: nil,
      collective_url: "invalid-url", 
      user: @user
    )
    assert_not collection.valid?
    assert_includes collection.errors[:collective_url], "must be a valid Open Collective URL"
  end

  test "collection should validate GitHub repo URL format" do
    collection = build(:collection,
      github_organization_url: nil, 
      github_repo_url: "invalid-url", 
      user: @user
    )
    assert_not collection.valid?
    assert_includes collection.errors[:github_repo_url], "must be a valid GitHub repository URL"
  end

  # Collection status tests
  test "collection should have proper ready status" do
    ready_collection = create(:collection, import_status: "completed", sync_status: "ready", user: @user)
    assert ready_collection.ready?
    
    syncing_collection = create(:collection, :syncing, user: @user)
    assert_not syncing_collection.ready?
    
    importing_collection = create(:collection, :importing, user: @user)
    assert_not importing_collection.ready?
  end

  # Collection name setting tests
  test "collection should set name from source URL" do
    collection = create(:collection, name: nil, github_organization_url: "https://github.com/testorg", user: @user)
    assert_equal "github.com/testorg", collection.name
    
    collection2 = create(:collection, 
      name: nil, 
      github_organization_url: nil,
      collective_url: "https://opencollective.com/testcollective", 
      user: @user
    )
    assert_equal "opencollective.com/testcollective", collection2.name
  end

  # Association tests  
  test "collection should belong to user" do
    assert_equal @user, @collection.user
  end

  test "collection should have many projects through collection_projects" do
    project1 = create(:project, :with_repository, url: "https://github.com/user1/repo1")
    project2 = create(:project, :with_repository, url: "https://github.com/user2/repo2")
    
    create(:collection_project, collection: @collection, project: project1)
    create(:collection_project, collection: @collection, project: project2)
    
    assert_includes @collection.projects, project1
    assert_includes @collection.projects, project2
    assert_equal 2, @collection.projects.count
  end

  # URL parameter tests
  test "collection should use uuid as parameter" do
    assert_equal @collection.uuid, @collection.to_param
  end

  # Scope tests
  test "visible scope should return public collections" do
    public_collection = create(:collection, :public, user: @user)
    private_collection = create(:collection, :private, user: @user)
    
    visible_collections = Collection.visible
    assert_includes visible_collections, public_collection
    assert_not_includes visible_collections, private_collection
  end
end
