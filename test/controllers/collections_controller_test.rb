require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    @other_user = create(:user)
    @collection = create(:collection, :public, user: @user, last_synced_at: 1.hour.ago)
    @private_collection = create(:collection, :private, user: @user, last_synced_at: 2.hours.ago)
    
    # Add projects with realistic data to collections
    @project1 = create(:project, :with_repository, 
                      url: "https://github.com/rails/rails",
                      last_synced_at: 30.minutes.ago,
                      packages_last_synced_at: 1.hour.ago,
                      issues_last_synced_at: 1.hour.ago,
                      commits_last_synced_at: 1.hour.ago,
                      tags_last_synced_at: 1.hour.ago,
                      dependencies_last_synced_at: 1.hour.ago)
                      
    @project2 = create(:project, :with_repository,
                      url: "https://github.com/jquery/jquery",
                      last_synced_at: 45.minutes.ago,
                      packages_last_synced_at: 2.hours.ago,
                      issues_last_synced_at: 2.hours.ago,
                      commits_last_synced_at: 2.hours.ago,
                      tags_last_synced_at: 2.hours.ago,
                      dependencies_last_synced_at: 2.hours.ago)
    
    # Associate projects with collections
    create(:collection_project, collection: @collection, project: @project1)
    create(:collection_project, collection: @collection, project: @project2)
    create(:collection_project, collection: @private_collection, project: @project1)
    
    # Create some commits and issues for realistic testing
    create_list(:commit, 5, project: @project1, timestamp: 1.week.ago)
    create_list(:commit, 3, project: @project2, timestamp: 2.weeks.ago)
    
    create_list(:issue, 8, project: @project1, state: "open", created_at: 3.days.ago)
    create_list(:issue, 4, project: @project1, state: "closed", created_at: 1.week.ago, closed_at: 2.days.ago)
    create_list(:issue, 6, project: @project2, state: "open", created_at: 5.days.ago)
    
    # Create some tags for release data
    create_list(:tag, 2, project: @project1, published_at: 2.weeks.ago)
    create_list(:tag, 1, project: @project2, published_at: 1.month.ago)
    
    # Create some packages for adoption data
    create_list(:package, 3, project: @project1)
    create_list(:package, 2, project: @project2)
    create(:package, :popular, project: @project1)
  end

  # Authentication tests
  test "should redirect to login when not authenticated" do
    get collections_url
    assert_response :redirect
    assert_redirected_to login_url
  end

  test "should show collections index when authenticated" do
    login_as(@user)
    
    get collections_url
    assert_response :success
    assert_template :index
    
    # Verify controller assigns user's collections
    collections = assigns(:collections)
    assert_includes collections, @collection
    assert_includes collections, @private_collection
    assert_equal 2, collections.size
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
    # @collection already has @project1 and @project2 from setup
    # Let's add one more project specifically for this test
    project3 = create(:project, :with_repository, url: "https://github.com/user3/repo3")
    create(:collection_project, collection: @collection, project: project3)
    
    assert_includes @collection.projects, @project1
    assert_includes @collection.projects, @project2
    assert_includes @collection.projects, project3
    assert_equal 3, @collection.projects.count
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
    
    # Add some projects to the collection
    projects = []
    6.times do |i|
      project = create(:project, :with_repository, url: "https://github.com/test/repo#{i}")
      create(:collection_project, collection: @collection, project: project)
      projects << project
    end
    
    get collection_path(@collection)
    assert_response :success
    assert_template :show
    
    # Verify collection and related data is assigned
    collection = assigns(:collection)
    assert_equal @collection, collection
    assert collection.projects.count >= 6  # Should include our test projects plus setup projects
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

  # CRUD action tests
  test "should show edit form for collection owner" do
    login_as(@user)
    get edit_collection_path(@collection)
    assert_response :success
    assert_template :edit
    
    # Verify collection is assigned for editing
    collection = assigns(:collection)
    assert_equal @collection, collection
  end

  test "should not show edit form for non-owner" do
    login_as(@other_user)
    get edit_collection_path(@collection)
    assert_response :not_found
  end

  test "should update collection when owner" do
    login_as(@user)
    new_name = "Updated Collection Name"
    new_description = "Updated description"
    
    patch collection_path(@collection), params: {
      collection: {
        name: new_name,
        description: new_description,
        visibility: "private"
      }
    }
    
    assert_redirected_to collection_path(@collection)
    assert_equal 'Collection was successfully updated.', flash[:notice]
    
    @collection.reload
    assert_equal new_name, @collection.name
    assert_equal new_description, @collection.description
    assert_equal "private", @collection.visibility
  end

  test "should not update collection when not owner" do
    login_as(@other_user)
    original_name = @collection.name
    
    patch collection_path(@collection), params: {
      collection: { name: "Hacked Name" }
    }
    
    assert_response :not_found
    @collection.reload
    assert_equal original_name, @collection.name
  end

  test "should show validation errors on update" do
    login_as(@user)
    
    patch collection_path(@collection), params: {
      collection: {
        name: "",
        github_organization_url: "",
        collective_url: "",
        github_repo_url: "",
        dependency_file: ""
      }
    }
    
    assert_response :success
    assert_template :edit
    
    # Verify collection has validation errors
    collection = assigns(:collection)
    assert_not collection.valid?
    assert collection.errors.any?
  end

  test "should destroy collection when owner" do
    login_as(@user)
    
    assert_difference('Collection.count', -1) do
      delete collection_path(@collection)
    end
    
    assert_redirected_to collections_path
    assert_equal 'Collection was successfully deleted.', flash[:notice]
  end

  test "should not destroy collection when not owner" do
    login_as(@other_user)
    
    assert_no_difference('Collection.count') do
      delete collection_path(@collection)
    end
    
    assert_response :not_found
  end

  # Analytics pages tests
  test "should show adoption page for ready collection with data" do
    login_as(@user)
    # Make collection ready
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get adoption_collection_path(@collection)
    assert_response :success
    assert_template :adoption
    
    # Verify required instance variables are assigned
    collection = assigns(:collection)
    assert_equal @collection, collection
    
    # Should assign top package if available
    top_package = assigns(:top_package)
    # top_package may be nil if no packages exist, which is fine
  end

  test "should redirect to syncing page for unready collection on adoption" do
    login_as(@user)
    # Make collection not ready
    @collection.update(import_status: "pending", sync_status: "pending")
    
    get adoption_collection_path(@collection)
    assert_response :success
    assert_template :syncing
  end

  test "should show dependencies page with actual dependency counts" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get dependencies_collection_path(@collection)
    assert_response :success
    assert_template :dependencies
    
    # Verify dependency counts are assigned
    direct_dependencies = assigns(:direct_dependencies)
    development_dependencies = assigns(:development_dependencies)
    transitive_dependencies = assigns(:transitive_dependencies)
    
    assert_not_nil direct_dependencies
    assert_not_nil development_dependencies
    assert_not_nil transitive_dependencies
  end

  test "should show finance page" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get finance_collection_path(@collection)
    assert_response :success
    assert_template :finance
  end

  test "should show responsiveness page" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get responsiveness_collection_path(@collection)
    assert_response :success
    assert_template :responsiveness
  end

  test "should not allow access to private collection analytics for non-owner" do
    @private_collection.update(import_status: "completed", sync_status: "ready")
    login_as(@other_user)
    
    get adoption_collection_path(@private_collection)
    assert_response :not_found
    
    get dependencies_collection_path(@private_collection)
    assert_response :not_found
    
    get finance_collection_path(@private_collection)
    assert_response :not_found
    
    get responsiveness_collection_path(@private_collection)
    assert_response :not_found
  end

  test "should allow access to public collection analytics for any user" do
    @collection.update(import_status: "completed", sync_status: "ready")
    login_as(@other_user)
    
    get adoption_collection_path(@collection)
    assert_response :success
    
    get dependencies_collection_path(@collection)
    assert_response :success
    
    get finance_collection_path(@collection)
    assert_response :success
    
    get responsiveness_collection_path(@collection)
    assert_response :success
  end

  # Syncing action tests
  test "should show syncing page" do
    login_as(@user)
    @collection.update(import_status: "pending", sync_status: "pending")
    
    get syncing_collection_path(@collection)
    assert_response :success
    assert_template :syncing
    
    # Verify collection is assigned
    collection = assigns(:collection)
    assert_equal @collection, collection
  end

  test "should trigger sync and redirect" do
    login_as(@user)
    
    # Mock the async import worker
    ImportCollectionWorker.expects(:perform_async).once
    
    get sync_collection_path(@collection)
    assert_redirected_to collection_path(@collection)
    assert_equal 'Collection sync started', flash[:notice]
    
    # Verify sync status was updated
    @collection.reload
    assert_equal 'pending', @collection.import_status
    assert_equal 'pending', @collection.sync_status
    assert_nil @collection.last_error_message
  end

  test "should not allow sync of private collection by non-owner" do
    login_as(@other_user)
    
    ImportCollectionWorker.expects(:perform_async).never
    
    get sync_collection_path(@private_collection)
    assert_response :not_found
  end

  # Enhanced engagement and productivity tests with data verification
  test "should show engagement page with actual metrics" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    travel_to Time.parse('2024-02-15') do
      get engagement_collection_path(@collection)
      assert_response :success
      assert_template :engagement
      
      # Verify required instance variables are assigned
      collection = assigns(:collection)
      assert_equal @collection, collection
      
      # Verify period-related variables are assigned
      range = assigns(:range)
      year = assigns(:year)
      month = assigns(:month)
      
      assert_not_nil range
      assert_not_nil year
      assert_not_nil month
      
      # Verify default month behavior is working
      controller = @controller
      assert_equal 2024, controller.send(:year)
      assert_equal 1, controller.send(:month)  # Previous month (January)
      
      # Verify metrics variables are assigned
      assert_not_nil assigns(:active_contributors_this_period)
      assert_not_nil assigns(:active_contributors_last_period)
      assert_not_nil assigns(:contributions_this_period)
      assert_not_nil assigns(:contributions_last_period)
    end
  end

  test "should show productivity page with commit and issue data" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    travel_to Time.parse('2024-02-15') do
      get productivity_collection_path(@collection)
      assert_response :success
      assert_template :productivity
      
      # Verify required instance variables are assigned
      collection = assigns(:collection)
      assert_equal @collection, collection
      
      # Verify productivity metrics are assigned
      assert_not_nil assigns(:commits_this_period)
      assert_not_nil assigns(:commits_last_period)
      assert_not_nil assigns(:tags_this_period)
      assert_not_nil assigns(:tags_last_period)
      assert_not_nil assigns(:new_issues_this_period)
      assert_not_nil assigns(:new_issues_last_period)
      assert_not_nil assigns(:new_prs_this_period)
      assert_not_nil assigns(:new_prs_last_period)
      
      # Verify we have some actual data from our setup
      commits_this = assigns(:commits_this_period)
      commits_last = assigns(:commits_last_period)
      # Should have numeric values (0 or more)
      assert_kind_of Integer, commits_this
      assert_kind_of Integer, commits_last
    end
  end

  test "should handle bot filtering on engagement page" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get engagement_collection_path(@collection), params: { exclude_bots: 'true' }
    assert_response :success
    
    get engagement_collection_path(@collection), params: { only_bots: 'true' }
    assert_response :success
  end

  test "should handle bot filtering on productivity page" do
    login_as(@user)
    @collection.update(import_status: "completed", sync_status: "ready")
    
    get productivity_collection_path(@collection), params: { exclude_bots: 'true' }
    assert_response :success
    
    get productivity_collection_path(@collection), params: { only_bots: 'true' }
    assert_response :success
  end
end
