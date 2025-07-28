require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    @other_user = create(:user)
    @collection = create(:collection, :public, user: @user, last_synced_at: 1.hour.ago)
    @private_collection = create(:collection, :private, user: @user, last_synced_at: 2.hours.ago)
  end

  # Authentication tests
  test "should redirect to login when not authenticated" do
    get collections_url
    assert_response :redirect
    assert_redirected_to login_url
  end

  test "should show collections index when authenticated" do
    login_as(@user)
    
    # Ensure user has collections to display (using the ones created in setup)
    assert @user.collections.include?(@collection)
    assert @user.collections.include?(@private_collection)
    
    get collections_url
    assert_response :success
    assert_template :index
    
    # Verify the collections are actually rendered
    assert_select '.listing', count: 2  # Should show both public and private collections for the owner
    assert_select 'h3.listing__title', text: @collection.name
    assert_select 'h3.listing__title', text: @private_collection.name
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

  # Controller validation error handling tests
  test "create should show validation errors for invalid GitHub organization URL" do
    login_as(@user)
    
    post collections_url, params: { 
      collection_type: "github",
      collection: { 
        github_organization_url: "invalid-url" 
      } 
    }
    
    assert_response :success
    assert_template :new
    assert_match(/must be a valid GitHub organization URL/, response.body)
  end

  test "create should show validation errors for invalid Open Collective URL" do
    login_as(@user)
    
    post collections_url, params: { 
      collection_type: "opencollective",
      collection: { 
        collective_url: "invalid-url" 
      } 
    }
    
    assert_response :success
    assert_template :new
    assert_match(/must be a valid Open Collective URL/, response.body)
  end

  test "create should show validation errors for invalid GitHub repo URL" do
    login_as(@user)
    
    post collections_url, params: { 
      collection_type: "dependency",
      collection: { 
        github_repo_url: "invalid-url" 
      } 
    }
    
    assert_response :success
    assert_template :new
    assert_match(/must be a valid GitHub repository URL/, response.body)
  end

  test "create should show validation error when no import source provided" do
    login_as(@user)
    
    post collections_url, params: { 
      collection_type: "github",
      collection: { 
        name: "Test Collection" 
      } 
    }
    
    assert_response :success
    assert_template :new
    assert_match(/You must provide a source/, response.body)
  end

  test "create should show validation errors for invalid SBOM file" do
    login_as(@user)
    
    # Create a mock file upload with invalid JSON
    invalid_file = Rack::Test::UploadedFile.new(
      StringIO.new("invalid json content"), 
      "application/json",
      original_filename: "invalid.json"
    )
    
    post collections_url, params: { 
      collection_type: "dependency",
      collection: { 
        dependency_file: invalid_file
      } 
    }
    
    assert_response :success
    assert_template :new
    assert_match(/must be a valid JSON SBOM file/, response.body)
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

  # Controller action tests
  test "should create collection with SBOM file upload" do
    login_as(@user)
    
    # Create a test SBOM file
    sbom_content = {
      "bomFormat" => "CycloneDX",
      "components" => [
        { "purl" => "pkg:gem/rails@7.0.0" },
        { "purl" => "pkg:npm/react@18.0.0" }
      ]
    }.to_json
    
    # Mock the import process to avoid actual API calls
    ImportCollectionWorker.expects(:perform_async).once
    
    assert_difference('Collection.count', 1) do
      post collections_path, params: {
        collection_type: "dependency",
        collection: {
          name: "Test SBOM Collection",
          description: "Test collection from SBOM upload",
          dependency_file: sbom_content,
          visibility: "public"
        }
      }
    end
    
    collection = Collection.last
    assert_equal "Test SBOM Collection", collection.name
    assert_equal sbom_content, collection.dependency_file
    assert_equal @user, collection.user
    assert_redirected_to collection_path(collection)
    assert_equal 'Collection was successfully created.', flash[:notice]
  end

  test "should create collection with SPDX SBOM file" do
    login_as(@user)
    
    # Create a test SPDX SBOM file
    spdx_content = {
      "spdxVersion" => "SPDX-2.3",
      "packages" => [
        {
          "externalRefs" => [
            { "referenceType" => "purl", "referenceLocator" => "pkg:gem/activerecord@7.0.0" }
          ]
        }
      ]
    }.to_json
    
    # Mock the import process
    ImportCollectionWorker.expects(:perform_async).once
    
    assert_difference('Collection.count', 1) do
      post collections_path, params: {
        collection_type: "dependency",
        collection: {
          name: "Test SPDX Collection", 
          description: "Test collection from SPDX SBOM",
          dependency_file: spdx_content,
          visibility: "private"
        }
      }
    end
    
    collection = Collection.last
    assert_equal "Test SPDX Collection", collection.name
    assert_equal spdx_content, collection.dependency_file
    assert_equal "private", collection.visibility
    assert_redirected_to collection_path(collection)
  end

  test "should handle invalid SBOM JSON in controller" do
    login_as(@user)
    
    # Invalid JSON content
    invalid_json = "{ invalid json content"
    
    # Should not create the collection due to validation
    assert_no_difference('Collection.count') do
      post collections_path, params: {
        collection_type: "dependency",
        collection: {
          name: "Invalid SBOM Collection",
          dependency_file: invalid_json,
          visibility: "public"
        }
      }
    end
    
    # Should show validation errors
    assert_response :success
    assert_template :new
    assert_match(/must be a valid JSON SBOM file/, response.body)
  end

  test "should require at least one source for dependency collection" do
    login_as(@user)
    
    # No dependency file or repo URL
    assert_no_difference('Collection.count') do
      post collections_path, params: {
        collection_type: "dependency",
        collection: {
          name: "Empty Collection",
          description: "Collection with no sources",
          dependency_file: "",
          github_repo_url: "",
          visibility: "public"
        }
      }
    end
    
    assert_response :success # Re-renders the form
    # The flash alert should be present
    assert flash[:alert].present?
    assert_includes flash[:alert], "You must provide a source"
  end

  test "should create collection with both SBOM and repo URL" do
    login_as(@user)
    
    sbom_content = {
      "bomFormat" => "CycloneDX",
      "components" => [{ "purl" => "pkg:gem/rails@7.0.0" }]
    }.to_json
    
    ImportCollectionWorker.expects(:perform_async).once
    
    assert_difference('Collection.count', 1) do
      post collections_path, params: {
        collection_type: "dependency",
        collection: {
          name: "Combined Collection",
          dependency_file: sbom_content,
          github_repo_url: "https://github.com/test/repo",
          visibility: "public"
        }
      }
    end
    
    collection = Collection.last
    assert_equal sbom_content, collection.dependency_file
    assert_equal "https://github.com/test/repo", collection.github_repo_url
    assert_redirected_to collection_path(collection)
  end

  test "should set name from SBOM when no name provided" do
    login_as(@user)
    
    sbom_content = {
      "bomFormat" => "CycloneDX",
      "components" => [{ "purl" => "pkg:gem/rails@7.0.0" }]
    }.to_json
    
    ImportCollectionWorker.expects(:perform_async).once
    
    post collections_path, params: {
      collection_type: "dependency",
      collection: {
        dependency_file: sbom_content,
        visibility: "public"
      }
    }
    
    collection = Collection.last
    assert_equal "SBOM from upload", collection.name
  end

  test "should require authentication for collection creation" do
    # Don't log in user
    initial_count = Collection.count
    
    post collections_path, params: {
      collection_type: "dependency",
      collection: {
        name: "Unauthorized Collection",
        dependency_file: '{"bomFormat": "CycloneDX"}',
        visibility: "public"
      }
    }
    
    assert_redirected_to login_path
    assert_equal initial_count, Collection.count # No new collections created
  end

  test "should show new collection form with dependency type" do
    login_as(@user)
    
    get new_collection_path, params: { collection_type: "dependency" }
    
    assert_response :success
    assert_select 'form[data-dependency-validation]'
    assert_select 'input[type="file"][name="collection[dependency_file]"]'
    assert_select 'input[name="collection[github_repo_url]"]'
    assert_select 'input[name="collection[name]"]'
    assert_select 'textarea[name="collection[description]"]'
  end

  test "can access collection show page" do
    login_as(@user)
    get collection_path(@collection)
    assert_response :success
    assert_template :show
  end

  test "collection show page renders with projects" do
    login_as(@user)
    
    # Add some projects to the collection to trigger the "more projects" link
    projects = []
    6.times do |i|
      project = create(:project, :with_repository, url: "https://github.com/test/repo#{i}")
      create(:collection_project, collection: @collection, project: project)
      projects << project
    end
    
    get collection_path(@collection)
    assert_response :success
    
    # Should show the "and X more..." link when there are more than 5 projects
    assert_select 'a[href*="projects"]', text: /and .* more/
  end
  
  test "projects view should show detailed sync status for projects" do
    login_as(@user)
    
    # Create projects with different sync states
    synced_project = create(:project, :with_repository, 
                           packages_last_synced_at: 30.minutes.ago,
                           issues_last_synced_at: 30.minutes.ago,
                           commits_last_synced_at: 30.minutes.ago,
                           tags_last_synced_at: 30.minutes.ago,
                           dependencies_last_synced_at: 30.minutes.ago,
                           last_synced_at: 30.minutes.ago)
    
    partially_synced_project = create(:project, :with_repository,
                                     packages_last_synced_at: 1.hour.ago,
                                     last_synced_at: nil)
    
    unsynced_project = create(:project, :without_repository, 
                             last_synced_at: nil)
    
    # Add projects to collection
    create(:collection_project, collection: @collection, project: synced_project)
    create(:collection_project, collection: @collection, project: partially_synced_project)
    create(:collection_project, collection: @collection, project: unsynced_project)
    
    get collection_projects_path(@collection)
    
    assert_response :success
    
    # Check that sync status badges are shown
    assert_select '.sync-overview'
    
    # Check for "Fully Synced" badge for the synced project
    assert_select '.badge.bg-success', text: /Fully Synced/
    
    # Check for "Syncing" badge for partially synced projects
    assert_select '.badge.bg-warning', text: /Syncing/
    
    # Check that individual sync status badges are present
    assert_select '.sync-details .badge', text: /Repo/
    assert_select '.sync-details .badge', text: /Packages/
    assert_select '.sync-details .badge', text: /Issues/
    assert_select '.sync-details .badge', text: /Commits/
    assert_select '.sync-details .badge', text: /Tags/
    assert_select '.sync-details .badge', text: /Deps/
    
    # Check that success and secondary badge styles are applied
    assert_select '.badge.bg-success.rounded-pill'
    assert_select '.badge.bg-secondary.rounded-pill'
  end

  test "should default to previous month for engagement page" do
    login_as(@user)
    
    travel_to Time.parse('2024-02-15') do
      get engagement_collection_url(@collection)
      assert_response :success
      
      # Should default to January 2024 (previous month)
      controller = @controller
      assert_equal 2024, controller.send(:year)
      assert_equal 1, controller.send(:month)
    end
  end

  test "should default to previous month for productivity page" do
    login_as(@user)
    
    travel_to Time.parse('2024-02-15') do
      get productivity_collection_url(@collection)
      assert_response :success
      
      # Should default to January 2024 (previous month)
      controller = @controller
      assert_equal 2024, controller.send(:year)
      assert_equal 1, controller.send(:month)
    end
  end

  test "should handle year boundary when defaulting to previous month" do
    login_as(@user)
    
    travel_to Time.parse('2024-01-15') do
      get engagement_collection_url(@collection)
      assert_response :success
      
      # Should default to December 2023 (previous month across year boundary)
      controller = @controller
      assert_equal 2023, controller.send(:year)
      assert_equal 12, controller.send(:month)
    end
  end
end
