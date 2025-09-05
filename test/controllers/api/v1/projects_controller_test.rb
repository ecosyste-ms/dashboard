require 'test_helper'

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Use unique URL to avoid conflicts with other tests
    @project = create(:project, 
      url: "https://github.com/test/api-project-#{SecureRandom.hex(8)}",
      repository: {
        "full_name" => "test/api-project",
        "name" => "api-project",
        "owner" => "test",
        "language" => "Ruby"
      })
    
    # Create some test data
    @issue = create(:issue, project: @project)
    @tag = create(:tag, project: @project, published_at: 1.day.ago)
    @commit = create(:commit, project: @project)
    @package = create(:package, project: @project)
    # Note: Advisory factory doesn't exist yet, create directly
    @advisory = @project.advisories.create!(
      uuid: SecureRandom.uuid,
      source_kind: 'test',
      title: 'Test Advisory',
      severity: 'high',
      published_at: 1.day.ago
    )
  end

  test 'should get index' do
    get api_v1_projects_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should show project' do
    get api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @project.url, json_response['url']
  end

  test 'should lookup project by url' do
    get lookup_api_v1_projects_url(url: @project.url), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @project.url, json_response['url']
  end

  test 'should get project issues' do
    get issues_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Check that our test issue is included
    issue_ids = json_response.map { |i| i['id'] }
    assert_includes issue_ids, @issue.id
  end

  test 'should get project releases' do
    get releases_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Check that our test tag is included
    tag_ids = json_response.map { |r| r['id'] }
    assert_includes tag_ids, @tag.id
  end

  test 'should get project commits' do
    get commits_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Check that our test commit is included
    commit_ids = json_response.map { |c| c['id'] }
    assert_includes commit_ids, @commit.id
  end

  test 'should get project packages' do
    get packages_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Check that our test package is included
    package_ids = json_response.map { |p| p['id'] }
    assert_includes package_ids, @package.id
  end

  test 'should get project advisories' do
    get advisories_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Check that our test advisory is included
    advisory_ids = json_response.map { |a| a['id'] }
    assert_includes advisory_ids, @advisory.id
  end

  test 'should ping project to sync' do
    # Mock the sync_async method
    Project.any_instance.expects(:sync_async)
    
    get ping_api_v1_project_url(@project), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'pong', json_response['message']
  end

  test 'should handle pagination for issues' do
    # Create more issues to test pagination
    create_list(:issue, 25, project: @project)
    
    get issues_api_v1_project_url(@project), params: { page: 1, per_page: 10 }, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 10, json_response.length
  end
end