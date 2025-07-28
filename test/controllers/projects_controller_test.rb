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
    project = create(:project, :without_repository, last_synced_at: nil)
    get project_url(project)  
    assert_response :success
    assert_template :syncing
    assert_select 'h2', text: /Syncing project data/
    assert_select '.sync-status-content'
  end

  test "should show syncing page for recently created project" do
    project = create(:project, :without_repository, last_synced_at: 2.hours.ago)
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
      post projects_url, params: { project: { url: 'https://github.com/test/repo' } }
    end
    
    project = Project.last
    assert_equal 'https://github.com/test/repo', project.url
    assert_redirected_to project_url(project)
    assert_equal 'Project was successfully created and is now syncing.', flash[:notice]
  end

  test "should redirect to existing project if already exists" do
    user = create(:user)
    login_as user
    existing_project = create(:project, url: 'https://github.com/test/repo')
    
    assert_no_difference('Project.count') do
      post projects_url, params: { project: { url: 'https://github.com/test/repo' } }
    end
    
    assert_redirected_to project_url(existing_project)
    assert_equal 'Project already exists in the system.', flash[:notice]
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
    get advisories_project_url(project)
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
end