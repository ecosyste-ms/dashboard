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

  test "should lookup and create new project" do
    user = create(:user)
    login_as(user)
    
    url = "https://github.com/newuser/newrepo"
    
    # Mock the sync_async method since we're testing the lookup functionality
    Project.any_instance.expects(:sync_async).once
    
    assert_difference('Project.count', 1) do
      post lookup_projects_url, params: { url: url }
    end
    
    project = Project.find_by(url: url.downcase)
    assert_redirected_to project_url(project)
  end

  test "should redirect to existing project on lookup" do
    user = create(:user)
    login_as(user)
    
    existing_project = create(:project, url: "https://github.com/existing/repo")
    
    assert_no_difference('Project.count') do
      post lookup_projects_url, params: { url: existing_project.url.upcase }
    end
    
    assert_redirected_to project_url(existing_project)
  end
end