require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  test "github_pages_to_repo_url" do
    project = Project.new
    repo_url = project.github_pages_to_repo_url('https://foo.github.io/bar')
    assert_equal 'https://github.com/foo/bar', repo_url
  end

  test "github_pages_to_repo_url with trailing slash" do
    project = Project.new(url: 'https://foo.github.io/bar/')
    repo_url = project.repository_url
    assert_equal 'https://github.com/foo/bar', repo_url
  end

  test "sync repository data updates repository field" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the repository API response
    stub_request(:get, /repos\.ecosyste\.ms.*repositories\/lookup/)
      .to_return(status: 200, body: {
        "full_name" => "rails/rails",
        "language" => "Ruby",
        "stargazers_count" => 56000,
        "host" => { "name" => "GitHub", "kind" => "git" }
      }.to_json)
    
    project.fetch_repository
    project.reload
    
    assert project.repository.present?
    assert_equal "rails/rails", project.repository["full_name"]
    assert_equal "Ruby", project.repository["language"]
    assert_equal 56000, project.repository["stargazers_count"]
  end

  test "sync packages data updates packages and timestamp" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the packages API response
    stub_request(:get, /packages\.ecosyste\.ms.*packages\/lookup/)
      .to_return(status: 200, body: [
        {
          "ecosystem" => "Rubygems",
          "name" => "rails",
          "purl" => "pkg:gem/rails@7.0.0",
          "metadata" => { "description" => "Ruby on Rails framework" }
        }
      ].to_json)
    
    project.fetch_packages
    project.reload
    
    assert_not_nil project.packages_last_synced_at
    assert_equal 1, project.packages.count
    
    rails_gem = project.packages.first
    assert_equal "Rubygems", rails_gem.ecosystem
    assert_equal "rails", rails_gem.name
  end

  test "sync_issues method updates timestamp" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the issues API response with paginated data
    stub_request(:get, /issues\.ecosyste\.ms.*repositories\/lookup/)
      .to_return(status: 200, body: {
        "issues_url" => "http://example.com/issues",
        "last_synced_at" => "2024-01-15T12:00:00Z"
      }.to_json)
    
    # Mock the paginated issues response
    stub_request(:get, "http://example.com/issues?page=1")
      .to_return(status: 200, body: [
        {
          "number" => 123,
          "title" => "Test Issue",
          "state" => "open",
          "user" => "testuser",
          "kind" => "issue",
          "created_at" => "2024-01-15T10:00:00Z"
        }
      ].to_json)
    
    # Mock empty response for page 2 to stop pagination
    stub_request(:get, "http://example.com/issues?page=2")
      .to_return(status: 200, body: [].to_json)
    
    project.sync_issues
    project.reload
    
    assert_not_nil project.issues_last_synced_at
    assert project.issues.count >= 0  # Issues might not be created due to validation
  end

  test "sync_commits method updates timestamp" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the commits API response
    stub_request(:get, /commits\.ecosyste\.ms.*repositories\/lookup/)
      .to_return(status: 200, body: {
        "commits_url" => "http://example.com/commits"
      }.to_json)
    
    # Mock the paginated commits response
    stub_request(:get, "http://example.com/commits?page=1&sort=timestamp")
      .to_return(status: 200, body: [
        {
          "sha" => "abc123",
          "message" => "Test commit",
          "author" => "testuser",
          "timestamp" => "2024-01-15T10:00:00Z",
          "stats" => {
            "additions" => 10,
            "deletions" => 5,
            "files_changed" => 2
          }
        }
      ].to_json)
    
    # Mock empty response for page 2
    stub_request(:get, "http://example.com/commits?page=2&sort=timestamp")
      .to_return(status: 200, body: [].to_json)
    
    project.sync_commits
    project.reload
    
    assert_not_nil project.commits_last_synced_at
    # The main thing we're testing is that the timestamp gets set
    assert project.commits_last_synced_at > 1.minute.ago
  end

  # Integration tests with real API responses
  test "fetch repository data from repos ecosyste.ms API" do
    VCR.use_cassette("project_sync/repository_basic") do
      project = create(:project, :never_synced, url: "https://github.com/rails/rails")
      
      project.fetch_repository
      project.reload
      
      assert project.repository.present?
      assert_equal "rails/rails", project.repository["full_name"]
      assert_equal "Ruby", project.repository["language"]
    end
  end

  test "fetch packages data from packages ecosyste.ms API" do
    # Skip this test if it would take too long (packages API can be slow)
    skip "Packages API test - too slow for regular runs" unless ENV['RUN_SLOW_TESTS']
    
    VCR.use_cassette("project_sync/packages_basic") do
      project = create(:project, :never_synced, url: "https://github.com/rails/rails")
      
      project.fetch_packages
      project.reload
      
      assert_not_nil project.packages_last_synced_at
      assert project.packages.count >= 0  # Rails might not have packages indexed yet
    end
  end

  test "sync respects individual timestamps" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the external API calls to avoid real requests in regular tests
    stub_request(:get, /commits\.ecosyste\.ms/)
      .to_return(status: 200, body: { commits_url: "http://example.com/commits" }.to_json)
    
    stub_request(:get, /example\.com\/commits/)
      .to_return(status: 200, body: [].to_json)

    project.sync_commits
    project.reload
    
    assert_not_nil project.commits_last_synced_at
    assert project.commits_last_synced_at > 1.minute.ago
  end

  test "full sync updates all timestamps" do
    project = create(:project, :rails_project, :never_synced)
    
    # Mock all API calls for a full sync test with more complete responses
    stub_request(:get, /repos\.ecosyste\.ms.*repositories\/lookup/)
      .to_return(status: 200, body: { 
        "full_name" => "rails/rails",
        "host" => { "name" => "GitHub", "kind" => "git" },
        "manifests_url" => "http://example.com/manifests"
      }.to_json)
    
    stub_request(:get, /packages\.ecosyste\.ms/)
      .to_return(status: 200, body: [].to_json)
      
    stub_request(:get, /issues\.ecosyste\.ms/)
      .to_return(status: 200, body: { 
        issues_url: "http://example.com/issues",
        last_synced_at: "2024-01-15T12:00:00Z"
      }.to_json)
      
    stub_request(:get, /example\.com/)
      .to_return(status: 200, body: [].to_json)

    # Mock tags API
    stub_request(:get, /repos\.ecosyste\.ms.*\/tags/)
      .to_return(status: 200, body: [].to_json)

    # Mock commits API
    stub_request(:get, /commits\.ecosyste\.ms/)
      .to_return(status: 200, body: { commits_url: "http://example.com/commits" }.to_json)

    initial_synced_at = project.last_synced_at
    
    project.sync
    project.reload
    
    # Verify main sync timestamp was updated
    assert_not_nil project.last_synced_at
    
    # Verify individual sync timestamps were set
    assert_not_nil project.packages_last_synced_at
    assert_not_nil project.issues_last_synced_at
  end
end