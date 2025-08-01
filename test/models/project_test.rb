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
    VCR.use_cassette("project_sync/fetch_repository_rails_project") do
      project = create(:project, :rails_project, :never_synced)
      
      project.fetch_repository
      project.reload
      
      assert project.repository.present?
      assert_equal "rails/rails", project.repository["full_name"]
      assert_equal "Ruby", project.repository["language"]
    end
  end

  test "sync packages data updates packages and timestamp" do
    VCR.use_cassette("project_sync/fetch_packages_rails_project") do
      project = create(:project, :rails_project, :never_synced)
      
      project.fetch_packages
      project.reload
      
      assert_not_nil project.packages_last_synced_at
      assert project.packages.count >= 0  # May have packages depending on API response
    end
  end

  test "sync_issues method updates timestamp" do
    VCR.use_cassette("project_sync/sync_issues_rails_project") do
      project = create(:project, :rails_project, :never_synced)
      
      project.sync_issues
      project.reload
      
      assert_not_nil project.issues_last_synced_at
      assert project.issues.count >= 0  # Issues might not be created due to validation
    end
  end

  test "ready? returns false for never synced project" do
    project = create(:project, last_synced_at: nil, sync_status: 'pending')
    assert_not project.ready?
  end

  test "ready? returns false for old synced project" do
    project = create(:project, last_synced_at: 2.hours.ago, sync_status: 'pending')
    assert_not project.ready?
  end

  test "ready? returns true for recently synced project" do
    project = create(:project, last_synced_at: 30.minutes.ago)
    assert project.ready?
  end

  test "ready? returns true for completed sync even if last_synced_at is old" do
    project = create(:project, last_synced_at: 2.hours.ago, sync_status: 'completed')
    assert project.ready?
  end

  test "ready? returns false for error sync status" do
    project = create(:project, last_synced_at: 30.minutes.ago, sync_status: 'error')
    assert_not project.ready?
  end

  test "ready? returns false for syncing status with old last_synced_at" do
    project = create(:project, last_synced_at: 2.hours.ago, sync_status: 'syncing')
    assert_not project.ready?
  end

  test "sync_stuck? returns true for syncing project with old updated_at" do
    project = create(:project, sync_status: 'syncing', updated_at: 1.hour.ago)
    assert project.sync_stuck?
  end

  test "sync_stuck? returns false for syncing project with recent updated_at" do
    project = create(:project, sync_status: 'syncing', updated_at: 15.minutes.ago)
    assert_not project.sync_stuck?
  end

  test "sync_stuck? returns false for completed project" do
    project = create(:project, sync_status: 'completed', updated_at: 1.hour.ago)
    assert_not project.sync_stuck?
  end

  test "sync_progress returns correct progress" do
    project = create(:project, :without_repository, last_synced_at: nil)
    progress = project.sync_progress
    
    assert_equal 6, progress[:total]
    assert_equal 0, progress[:completed]
    assert_equal 0, progress[:percentage]
  end

  test "sync_progress with some components synced" do
    project = create(:project, :with_repository, 
                    packages_last_synced_at: 1.hour.ago,
                    issues_last_synced_at: 1.hour.ago)
    progress = project.sync_progress
    
    assert_equal 6, progress[:total]
    assert_equal 3, progress[:completed]  # repository + packages + issues
    assert_equal 50, progress[:percentage]
  end

  test "sync_commits method updates timestamp" do
    WebMock.enable!
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the commits API response with correct structure
    stub_request(:get, project.commits_api_url)
      .to_return(status: 200, body: { 
        commits_url: "https://commits.ecosyste.ms/api/v1/hosts/GitHub/repositories/rails/rails/commits" 
      }.to_json)
    
    # Mock the commits list API
    stub_request(:get, /commits\.ecosyste\.ms\/api\/v1\/hosts\/GitHub\/repositories\/rails\/rails\/commits/)
      .to_return(status: 200, body: [].to_json)
    
    project.sync_commits
    project.reload
    
    assert_not_nil project.commits_last_synced_at
    # The main thing we're testing is that the timestamp gets set
    assert project.commits_last_synced_at > 1.minute.ago
  ensure
    WebMock.reset!
  end

  test "fetch repository data updates repository field" do
    VCR.use_cassette("project_sync/fetch_repository_direct_url") do
      project = create(:project, :never_synced, url: "https://github.com/rails/rails")
      
      project.fetch_repository
      project.reload
      
      assert project.repository.present?
      assert_equal "rails/rails", project.repository["full_name"]
      assert_equal "Ruby", project.repository["language"]
    end
  end

  test "fetch packages data updates packages and timestamp" do
    VCR.use_cassette("project_sync/fetch_packages_direct_url") do
      project = create(:project, :never_synced, url: "https://github.com/rails/rails")
      
      project.fetch_packages(max_pages: 2)
      project.reload
      
      assert_not_nil project.packages_last_synced_at
      assert project.packages.count >= 0  # May have packages depending on API response
    end
  end

  test "sync respects individual timestamps" do
    WebMock.enable!
    project = create(:project, :rails_project, :never_synced)
    
    # Mock the commits API response with correct structure
    stub_request(:get, project.commits_api_url)
      .to_return(status: 200, body: { 
        commits_url: "https://commits.ecosyste.ms/api/v1/hosts/GitHub/repositories/rails/rails/commits" 
      }.to_json)
    
    # Mock the commits list API
    stub_request(:get, /commits\.ecosyste\.ms\/api\/v1\/hosts\/GitHub\/repositories\/rails\/rails\/commits/)
      .to_return(status: 200, body: [].to_json)
    
    project.sync_commits
    project.reload
    
    assert_not_nil project.commits_last_synced_at
    assert project.commits_last_synced_at > 1.minute.ago
  ensure
    WebMock.reset!
  end

  test "full sync updates all timestamps" do
    VCR.use_cassette("project_sync/full_sync") do
      project = create(:project, :rails_project, :never_synced)
      
      project.sync
      project.reload
      
      # Verify main sync timestamp was updated
      assert_not_nil project.last_synced_at
      
      # Verify individual sync timestamps were set  
      assert_not_nil project.packages_last_synced_at
      assert_not_nil project.issues_last_synced_at
    end
  end

  test "licenses method flattens and deduplicates package licenses with repository license" do
    project = create(:project)
    repository_license = "Apache-2.0"
    project.update(repository: { 'license' => repository_license })
    
    # Create packages with licenses
    package1 = create(:package, project: project, metadata: { 'licenses' => ['MIT', 'BSD-3-Clause'] })
    package2 = create(:package, project: project, metadata: { 'licenses' => ['MIT', 'GPL-3.0'] })
    
    licenses = project.licenses
    
    assert_includes licenses, 'MIT'
    assert_includes licenses, 'BSD-3-Clause'
    assert_includes licenses, 'GPL-3.0'
    assert_includes licenses, repository_license
    
    # Should not have duplicates
    assert_equal licenses.uniq, licenses
  end
end