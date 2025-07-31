require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should show project" do
    project = create(:project, :with_repository)
    get project_url(project)
    assert_response :success
  end

  test "should show meta page" do
    project = create(:project, :with_repository)
    get meta_project_url(project)
    assert_response :success
  end

  test "should show meta page when repository is nil" do
    project = create(:project, :without_repository)
    get meta_project_url(project)
    assert_response :success
    assert_select 'span', text: /Repository: Never/
    assert_select 'span', text: /Tags: Never/
  end

  test "should sync project successfully" do
    project = create(:project, :with_repository)
    
    # Mock the sync method to succeed
    Project.any_instance.expects(:sync).once
    
    get sync_project_url(project)
    assert_redirected_to project_url(project)
    assert_equal 'Project synced', flash[:notice]
  end

  test "should handle sync errors gracefully" do
    project = create(:project, :with_repository)
    
    # Mock the sync method to raise an error
    Project.any_instance.expects(:sync).raises(StandardError.new("Connection timeout"))
    
    get sync_project_url(project)
    assert_redirected_to project_url(project)
    assert_equal 'Sync failed: Connection timeout', flash[:alert]
  end

  test "should show syncing page for unsynced project" do
    project = create(:project, :without_repository, last_synced_at: nil, sync_status: 'pending')
    get project_url(project)  
    assert_response :success
    assert_template :syncing
    assert_select 'h2', text: /Syncing project data/
    assert_select '.sync-status-content'
  end

  test "should show syncing page for recently created project" do
    project = create(:project, :without_repository, last_synced_at: 2.hours.ago, sync_status: 'pending')
    get project_url(project)
    assert_response :success
    assert_template :syncing
  end

  test "should show regular project page for synced project" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get project_url(project)
    assert_response :success
    assert_template :show
  end

  test "should show syncing page directly" do
    project = create(:project, :without_repository)
    get syncing_project_url(project)
    assert_response :success
    assert_template :syncing
    assert_select 'h2', text: /Syncing project data/
  end

  test "should show new project form when logged in" do
    user = create(:user)
    login_as user
    
    get new_project_url
    assert_response :success
    assert_template :new
    assert_select 'h1', text: /Add a new project/
    assert_select 'input[name="project[url]"]'
  end

  test "should require authentication for new project form" do
    get new_project_url
    assert_redirected_to login_url
  end

  test "should create new project when logged in" do
    user = create(:user)
    login_as user
    
    assert_difference('Project.count') do
      assert_difference('UserProject.count', 1) do
        post projects_url, params: { project: { url: 'https://github.com/test/repo' } }
      end
    end
    
    project = Project.last
    assert_equal 'https://github.com/test/repo', project.url
    assert_redirected_to project_url(project)
    assert_equal 'Project was successfully created and added to your list.', flash[:notice]
    
    # Verify the project was added to user's list
    assert user.user_projects.exists?(project: project)
  end

  test "should redirect to existing project if already exists" do
    user = create(:user)
    login_as user
    existing_project = create(:project, url: 'https://github.com/test/repo')
    
    assert_no_difference('Project.count') do
      assert_difference('UserProject.count', 1) do
        post projects_url, params: { project: { url: 'https://github.com/test/repo' } }
      end
    end
    
    assert_redirected_to project_url(existing_project)
    assert_equal 'Project added to your list.', flash[:notice]
    
    # Verify the project was added to user's list
    assert user.user_projects.exists?(project: existing_project)
  end

  test "should handle case insensitive URLs" do
    user = create(:user)
    login_as user
    existing_project = create(:project, url: 'https://github.com/test/repo')
    
    assert_no_difference('Project.count') do
      post projects_url, params: { project: { url: 'HTTPS://GITHUB.COM/TEST/REPO' } }
    end
    
    assert_redirected_to project_url(existing_project)
  end

  test "should require authentication for project creation" do
    post projects_url, params: { project: { url: 'https://github.com/test/repo' } }
    assert_redirected_to login_url
  end

  test "should show validation errors for invalid project" do
    user = create(:user)
    login_as user
    
    post projects_url, params: { project: { url: '' } }
    assert_response :success
    assert_template :new
    assert_select '.alert-danger'
  end

  test "should pre-fill URL in new project form when passed as parameter" do
    user = create(:user)
    login_as user
    
    url = "https://github.com/test/repo"
    get new_project_url(url: url)
    assert_response :success
    assert_select 'input[name="project[url]"][value="' + url + '"]'
  end

  test "should show project packages" do
    project = create(:project, :with_repository)
    get packages_project_url(project)
    assert_response :success
  end

  test "should show project commits" do
    project = create(:project, :with_repository)
    get commits_project_url(project)
    assert_response :success
  end

  test "should show project issues" do
    project = create(:project, :with_repository)
    get issues_project_url(project)
    assert_response :success
  end

  test "should show project releases" do
    project = create(:project, :with_repository)
    get releases_project_url(project)
    assert_response :success
  end

  test "should show project advisories" do
    project = create(:project, :with_repository)
    get security_project_url(project)
    assert_response :success
  end

  test "should show project security" do
    project = create(:project, :with_repository)
    get security_project_url(project)
    assert_response :success
  end

  test "should redirect to new project form for non-existent project" do
    url = "https://github.com/newuser/newrepo"
    
    # No authentication required for lookup
    assert_no_difference('Project.count') do
      post lookup_projects_url, params: { url: url }
    end
    
    assert_redirected_to new_project_path(url: url)
  end

  test "should redirect to existing project on lookup without authentication" do
    existing_project = create(:project, url: "https://github.com/existing/repo")
    
    # No authentication required for lookup of existing projects
    assert_no_difference('Project.count') do
      post lookup_projects_url, params: { url: existing_project.url.upcase }
    end
    
    assert_redirected_to project_url(existing_project)
  end

  test "should flow from lookup to new project form to creation when authenticated" do
    user = create(:user)
    url = "https://github.com/flow/test"
    
    # Step 1: Anonymous lookup redirects to new project form
    post lookup_projects_url, params: { url: url }
    assert_redirected_to new_project_path(url: url)
    
    # Step 2: Accessing new project form requires login
    get new_project_path(url: url)
    assert_redirected_to login_url
    
    # Step 3: After login, can access form with pre-filled URL
    login_as user
    get new_project_path(url: url)
    assert_response :success
    assert_select 'input[name="project[url]"][value="' + url + '"]'
    
    # Step 4: Create project successfully
    assert_difference('Project.count') do
      post projects_url, params: { project: { url: url } }
    end
    
    project = Project.last
    assert_equal url, project.url
    assert_redirected_to project_url(project)
  end

  test "should show engagement page with comprehensive metrics" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    
    # Add some issues for testing engagement metrics
    create_list(:issue, 5, project: project, state: "open", created_at: 2.weeks.ago)
    create_list(:issue, 3, project: project, state: "closed", created_at: 3.weeks.ago, closed_at: 1.week.ago)
    
    travel_to Time.parse('2024-02-15') do
      get engagement_project_url(project)
      assert_response :success
      assert_template :engagement
      
      # Verify project is assigned
      assigned_project = assigns(:project)
      assert_equal project, assigned_project
      
      # Verify period variables are assigned
      assert_not_nil assigns(:range)
      assert_not_nil assigns(:year)
      assert_not_nil assigns(:month)
      assert_not_nil assigns(:period_date)
      
      # Verify engagement metrics are assigned
      assert_not_nil assigns(:active_contributors_this_period)
      assert_not_nil assigns(:active_contributors_last_period)
      assert_not_nil assigns(:contributions_this_period)
      assert_not_nil assigns(:contributions_last_period)
      assert_not_nil assigns(:issue_authors_this_period)
      assert_not_nil assigns(:issue_authors_last_period)
      assert_not_nil assigns(:pr_authors_this_period)
      assert_not_nil assigns(:pr_authors_last_period)
      assert_not_nil assigns(:all_time_contributors)
      
      # Verify default month behavior
      controller = @controller
      assert_equal 2024, controller.send(:year)
      assert_equal 1, controller.send(:month)  # Previous month (January)
    end
  end

  test "should show productivity page with comprehensive metrics" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    
    # Add test data for productivity metrics
    create_list(:commit, 8, project: project, timestamp: 2.weeks.ago)
    create_list(:tag, 2, project: project, published_at: 3.weeks.ago)
    create_list(:issue, 6, project: project, state: "open", created_at: 2.weeks.ago)
    create_list(:issue, 4, project: project, state: "closed", created_at: 3.weeks.ago, closed_at: 1.week.ago)
    
    travel_to Time.parse('2024-02-15') do
      get productivity_project_url(project)
      assert_response :success
      assert_template :productivity
      
      # Verify project is assigned
      assigned_project = assigns(:project)
      assert_equal project, assigned_project
      
      # Verify productivity metrics are assigned
      assert_not_nil assigns(:commits_this_period)
      assert_not_nil assigns(:commits_last_period)
      assert_not_nil assigns(:tags_this_period)
      assert_not_nil assigns(:tags_last_period)
      assert_not_nil assigns(:avg_commits_per_author_this_period)
      assert_not_nil assigns(:avg_commits_per_author_last_period)
      assert_not_nil assigns(:new_issues_this_period)
      assert_not_nil assigns(:new_issues_last_period)
      assert_not_nil assigns(:new_prs_this_period)
      assert_not_nil assigns(:new_prs_last_period)
      
      # Verify metrics are numeric
      assert_kind_of Integer, assigns(:commits_this_period)
      assert_kind_of Integer, assigns(:commits_last_period)
      assert assigns(:avg_commits_per_author_this_period).is_a?(Numeric)
      assert assigns(:avg_commits_per_author_last_period).is_a?(Numeric)
      
      # Verify default month behavior
      controller = @controller
      assert_equal 2024, controller.send(:year)
      assert_equal 1, controller.send(:month)  # Previous month (January)
    end
  end

  test "should handle year boundary when defaulting to previous month" do
    project = create(:project, :with_repository)
    
    travel_to Time.parse('2024-01-15') do
      get engagement_project_url(project)
      assert_response :success
      
      # Should default to December 2023 (previous month across year boundary)
      controller = @controller
      assert_equal 2023, controller.send(:year)
      assert_equal 12, controller.send(:month)
    end
  end

  # Analytics pages tests
  test "should show adoption page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get adoption_project_url(project)
    assert_response :success
    assert_template :adoption
    
    # Verify required instance variables are assigned
    assigned_project = assigns(:project)
    assert_equal project, assigned_project
    
    # Should assign top package if available
    top_package = assigns(:top_package)
    # top_package may be nil if no packages exist, which is fine
  end

  test "should show dependencies page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get dependencies_project_url(project)
    assert_response :success
    assert_template :dependencies
    
    # Verify project and dependency counts are assigned
    assigned_project = assigns(:project)
    assert_equal project, assigned_project
    
    direct_dependencies = assigns(:direct_dependencies)
    development_dependencies = assigns(:development_dependencies)
    transitive_dependencies = assigns(:transitive_dependencies)
    
    assert_not_nil direct_dependencies
    assert_not_nil development_dependencies
    assert_not_nil transitive_dependencies
  end
  
  test "should show dependencies page with direct filter" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get dependencies_project_url(project, filter: 'direct')
    assert_response :success
    assert_template :dependencies
    
    # Verify filter parameter is preserved
    assert_equal 'direct', @request.params[:filter]
  end
  
  test "should show dependencies page with development filter" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get dependencies_project_url(project, filter: 'development')
    assert_response :success
    assert_template :dependencies
    
    # Verify filter parameter is preserved
    assert_equal 'development', @request.params[:filter]
  end
  
  test "should show dependencies page with transitive filter" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get dependencies_project_url(project, filter: 'transitive')
    assert_response :success
    assert_template :dependencies
    
    # Verify filter parameter is preserved
    assert_equal 'transitive', @request.params[:filter]
  end

  test "should show finance page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get finance_project_url(project)
    assert_response :success
    assert_template :finance
    
    # Verify project is assigned
    assigned_project = assigns(:project)
    assert_equal project, assigned_project
    
    # Finance variables may be nil if no collective/sponsors exist
    # This is expected behavior
  end

  test "should show responsiveness page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    get responsiveness_project_url(project)
    assert_response :success
    assert_template :responsiveness
    
    # Verify project is assigned
    assigned_project = assigns(:project)
    assert_equal project, assigned_project
    
    # Verify responsiveness metrics are assigned
    assert_not_nil assigns(:time_to_close_prs_this_period)
    assert_not_nil assigns(:time_to_close_prs_last_period)
    assert_not_nil assigns(:time_to_close_issues_this_period)
    assert_not_nil assigns(:time_to_close_issues_last_period)
  end

  test "should redirect to syncing for unready project on analytics pages" do
    project = create(:project, :without_repository, last_synced_at: nil, sync_status: 'pending')
    
    # Test that analytics pages redirect to syncing for unready projects
    get adoption_project_url(project)
    assert_response :success
    assert_template :syncing
    
    get dependencies_project_url(project)
    assert_response :success
    assert_template :syncing
    
    get finance_project_url(project)
    assert_response :success
    assert_template :syncing
    
    get responsiveness_project_url(project)
    assert_response :success
    assert_template :syncing
  end

  # Bot filtering tests
  test "should handle bot filtering on engagement page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create_list(:issue, 3, project: project, state: "open", created_at: 2.weeks.ago)
    
    # Test exclude_bots parameter
    get engagement_project_url(project), params: { exclude_bots: 'true' }
    assert_response :success
    assert_template :engagement
    
    # Test only_bots parameter  
    get engagement_project_url(project), params: { only_bots: 'true' }
    assert_response :success
    assert_template :engagement
  end

  test "should handle bot filtering on productivity page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create_list(:issue, 3, project: project, state: "open", created_at: 2.weeks.ago)
    
    # Test exclude_bots parameter
    get productivity_project_url(project), params: { exclude_bots: 'true' }
    assert_response :success
    assert_template :productivity
    
    # Test only_bots parameter
    get productivity_project_url(project), params: { only_bots: 'true' }
    assert_response :success
    assert_template :productivity
  end

  test "should handle bot filtering on responsiveness page" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create_list(:issue, 3, project: project, state: "closed", created_at: 3.weeks.ago, closed_at: 2.weeks.ago)
    
    # Test exclude_bots parameter
    get responsiveness_project_url(project), params: { exclude_bots: 'true' }
    assert_response :success
    assert_template :responsiveness
    
    # Test only_bots parameter
    get responsiveness_project_url(project), params: { only_bots: 'true' }
    assert_response :success
    assert_template :responsiveness
  end

  # Nested collection routes tests
  test "should access project through collection context" do
    user = create(:user)
    collection = create(:collection, :public, user: user)
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create(:collection_project, collection: collection, project: project)
    
    # Test nested show route
    get collection_project_url(collection, project)
    assert_response :success
    assert_template :show
    
    # Verify both collection and project are assigned
    assigned_collection = assigns(:collection)
    assigned_project = assigns(:project)
    assert_equal collection, assigned_collection
    assert_equal project, assigned_project
  end

  test "should access project analytics through collection context" do
    user = create(:user)
    collection = create(:collection, :public, user: user)
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create(:collection_project, collection: collection, project: project)
    
    # Test nested analytics routes
    get engagement_collection_project_url(collection, project)
    assert_response :success
    assert_template :engagement
    
    get productivity_collection_project_url(collection, project)
    assert_response :success
    assert_template :productivity
    
    get adoption_collection_project_url(collection, project)
    assert_response :success
    assert_template :adoption
    
    # Verify collection context is maintained
    assigned_collection = assigns(:collection)
    assert_equal collection, assigned_collection
  end

  test "should not access private collection projects by non-owner" do
    owner = create(:user)
    other_user = create(:user)
    private_collection = create(:collection, :private, user: owner)
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    create(:collection_project, collection: private_collection, project: project)
    
    # The controller should return 404 for non-owner accessing private collection
    get collection_project_url(private_collection, project)
    assert_response :not_found
  end

  # Show page with realistic data test
  test "should show project page with comprehensive data" do
    project = create(:project, :with_repository, last_synced_at: 30.minutes.ago)
    
    # Add realistic test data
    create_list(:commit, 10, project: project, timestamp: 1.month.ago)
    create_list(:issue, 8, project: project, state: "open", created_at: 2.weeks.ago)
    create_list(:issue, 5, project: project, state: "closed", created_at: 3.weeks.ago, closed_at: 1.week.ago)
    create_list(:package, 3, project: project)
    create_list(:tag, 2, project: project, published_at: 1.month.ago)
    
    get project_url(project)
    assert_response :success
    assert_template :show
    
    # Verify project data is assigned
    assigned_project = assigns(:project)
    assert_equal project, assigned_project
    
    # Verify chart data is assigned
    assert_not_nil assigns(:commits_per_period)
    assert_not_nil assigns(:commits_this_period)
    assert_not_nil assigns(:commits_last_period)
    
    # Verify project has the data we created
    assert_equal 10, project.commits.count
    assert_equal 13, project.issues.count  # 8 open + 5 closed
    assert_equal 3, project.packages.count
    assert_equal 2, project.tags.count
  end
end