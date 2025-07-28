require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @cyclone_dx_sbom = {
      "bomFormat" => "CycloneDX",
      "components" => [
        { "purl" => "pkg:gem/rails@7.0.0" },
        { "purl" => "pkg:npm/react@18.0.0" },
        { "purl" => "pkg:github/rails/rails@v7.0.0" }
      ]
    }.to_json

    @spdx_sbom = {
      "spdxVersion" => "SPDX-2.3",
      "packages" => [
        {
          "externalRefs" => [
            { "referenceType" => "purl", "referenceLocator" => "pkg:gem/activerecord@7.0.0" }
          ]
        },
        {
          "externalRefs" => [
            { "referenceType" => "purl", "referenceLocator" => "pkg:npm/lodash@4.17.21" }
          ]
        }
      ]
    }.to_json
  end

  test "should import projects from CycloneDX SBOM" do
    collection = @user.collections.create!(
      name: "Test SBOM Collection",
      dependency_file: @cyclone_dx_sbom
    )
    
    # Mock Package.package_url to return relations with first() results
    mock_rails_relation = mock()
    mock_rails_package = OpenStruct.new(repository_url: "https://github.com/rails/rails", project: nil)
    mock_rails_relation.stubs(:first).returns(mock_rails_package)
    
    mock_react_relation = mock()
    mock_react_package = OpenStruct.new(repository_url: "https://github.com/facebook/react", project: nil)
    mock_react_relation.stubs(:first).returns(mock_react_package)
    
    empty_relation = mock()
    empty_relation.stubs(:first).returns(nil)
    
    Package.stubs(:package_url).with("pkg:gem/rails@7.0.0").returns(mock_rails_relation)
    Package.stubs(:package_url).with("pkg:npm/react@18.0.0").returns(mock_react_relation)
    Package.stubs(:package_url).with("pkg:github/rails/rails@v7.0.0").returns(empty_relation)
    
    # Mock the worker to avoid background job execution
    SyncProjectWorker.expects(:perform_async).at_least_once
    
    # Perform the import
    collection.import_from_dependency_file
    
    # Verify projects were created
    assert collection.projects.count > 0
    
    # Check if specific projects were imported
    rails_project = collection.projects.find_by(url: "https://github.com/rails/rails")
    react_project = collection.projects.find_by(url: "https://github.com/facebook/react")
    
    assert rails_project, "Rails project should be imported"
    assert react_project, "React project should be imported"
  end

  test "should import projects from SPDX SBOM" do
    collection = @user.collections.create!(
      name: "Test SPDX Collection", 
      dependency_file: @spdx_sbom
    )
    
    # Mock the Package.package_url scope to return empty relations (no local packages found)
    Package.stubs(:package_url).returns(Package.none)
    
    # Stub the HTTP requests for package lookup
    stub_request(:get, "https://packages.ecosyste.ms/api/v1/packages/lookup?purl=pkg:gem/activerecord@7.0.0")
      .to_return(status: 200, body: [{ "repository_url" => "https://github.com/rails/rails" }].to_json)
    
    stub_request(:get, "https://packages.ecosyste.ms/api/v1/packages/lookup?purl=pkg:npm/lodash@4.17.21")
      .to_return(status: 200, body: [{ "repository_url" => "https://github.com/lodash/lodash" }].to_json)
    
    # Mock the worker
    SyncProjectWorker.expects(:perform_async).at_least_once
    
    # Perform the import
    collection.import_from_dependency_file
    
    # Verify projects were created
    assert collection.projects.count > 0
    
    rails_project = collection.projects.find_by(url: "https://github.com/rails/rails")
    lodash_project = collection.projects.find_by(url: "https://github.com/lodash/lodash")
    
    assert rails_project, "Rails project should be imported"
    assert lodash_project, "Lodash project should be imported"
  end

  test "should handle invalid SBOM JSON gracefully" do
    collection = @user.collections.create!(
      name: "Invalid SBOM Collection",
      dependency_file: "invalid json content"
    )
    
    assert_raises(JSON::ParserError) do
      collection.import_from_dependency_file
    end
    
    collection.reload
    assert_equal 'error', collection.import_status
    assert_includes collection.last_error_message, "Invalid SBOM file format"
  end

  test "should handle empty dependency file" do
    # Create collection with valid source first, then clear dependency_file
    collection = @user.collections.create!(
      name: "Empty SBOM Collection",
      dependency_file: @cyclone_dx_sbom
    )
    
    # Clear the dependency file to test empty case
    collection.update_column(:dependency_file, "")
    
    # Should return early and not raise error
    assert_nothing_raised do
      collection.import_from_dependency_file
    end
  end

  test "should extract PURLs from CycloneDX SBOM" do
    json = JSON.parse(@cyclone_dx_sbom)
    
    purls = Sbom.extract_purls_from_json(json)
    
    expected_purls = [
      "pkg:gem/rails@7.0.0",
      "pkg:npm/react@18.0.0", 
      "pkg:github/rails/rails@v7.0.0"
    ]
    
    assert_equal expected_purls, purls
  end

  test "should extract PURLs from SPDX SBOM" do
    json = JSON.parse(@spdx_sbom)
    
    purls = Sbom.extract_purls_from_json(json)
    
    expected_purls = [
      "pkg:gem/activerecord@7.0.0",
      "pkg:npm/lodash@4.17.21"
    ]
    
    assert_equal expected_purls, purls
  end

  test "should handle GitHub Actions PURLs correctly" do
    github_actions_sbom = {
      "bomFormat" => "CycloneDX",
      "components" => [
        { "purl" => "pkg:github/actions/checkout@v4" },
        { "purl" => "pkg:github/actions/setup-node@v4.4.0" },
        { "purl" => "pkg:github/andrew/ruby-upgrade-action@main" }
      ]
    }.to_json
    
    json = JSON.parse(github_actions_sbom)
    
    purls = Sbom.extract_purls_from_json(json)
    urls = Sbom.fetch_project_urls_from_purls(purls)
    
    expected_urls = [
      "https://github.com/actions/checkout",
      "https://github.com/actions/setup-node", 
      "https://github.com/andrew/ruby-upgrade-action"
    ]
    
    assert_equal expected_urls.sort, urls.sort
  end

  test "should handle pkg:githubactions PURLs via API lookup" do
    githubactions_sbom = {
      "bomFormat" => "CycloneDX", 
      "components" => [
        { "purl" => "pkg:githubactions/actions/checkout@v4" },
        { "purl" => "pkg:githubactions/actions/setup-node@v4.4.0" }
      ]
    }.to_json
    
    # Stub the HTTP requests for GitHub Actions API lookup
    stub_request(:get, "https://packages.ecosyste.ms/api/v1/packages/lookup?purl=pkg:githubactions/actions/checkout@v4")
      .to_return(status: 200, body: [{ "repository_url" => "https://github.com/actions/checkout" }].to_json)
    
    stub_request(:get, "https://packages.ecosyste.ms/api/v1/packages/lookup?purl=pkg:githubactions/actions/setup-node@v4.4.0")
      .to_return(status: 200, body: [{ "repository_url" => "https://github.com/actions/setup-node" }].to_json)
    
    json = JSON.parse(githubactions_sbom)
    purls = Sbom.extract_purls_from_json(json)
    urls = Sbom.fetch_project_urls_from_purls(purls)
    
    expected_urls = [
      "https://github.com/actions/checkout",
      "https://github.com/actions/setup-node"
    ]
    
    assert_equal expected_urls.sort, urls.sort
  end

  test "import_github_org class method requires user parameter" do
    user1 = create(:user)
    
    # Mock the HTTP request for GitHub org repos
    stub_request(:get, "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/testorg1/repositories?per_page=100&page=1")
      .to_return(status: 200, body: [].to_json)
    
    # Create collection with user1
    collection1 = Collection.import_github_org("testorg1", user: user1)
    
    assert_not_nil collection1, "Collection1 should not be nil"
    assert collection1.persisted?, "Collection1 should be persisted"
    assert_equal user1, collection1.user
    assert_equal "testorg1", collection1.name
    assert_equal "Collection of repositories for testorg1", collection1.description
  end

  test "should set last_synced_at when all projects are synced" do
    collection = @user.collections.create!(
      name: "Test Sync Collection",
      dependency_file: @cyclone_dx_sbom,
      sync_status: 'syncing'
    )
    
    # Create some projects for this collection without last_synced_at
    project1 = create(:project, url: "https://github.com/test/project1", last_synced_at: nil)
    project2 = create(:project, url: "https://github.com/test/project2", last_synced_at: nil)
    
    collection.collection_projects.create!(project: project1)
    collection.collection_projects.create!(project: project2)
    
    # Initially, collection should not have last_synced_at set
    assert_nil collection.last_synced_at
    
    # Mark first project as synced
    project1.update!(last_synced_at: Time.current)
    collection.check_and_update_sync_status
    
    # Collection should still not have last_synced_at set (not all projects synced)
    collection.reload
    assert_nil collection.last_synced_at
    assert_equal 'syncing', collection.sync_status
    
    # Mark second project as synced
    project2.update!(last_synced_at: Time.current)
    collection.check_and_update_sync_status
    
    # Collection should now have last_synced_at set
    collection.reload
    assert_not_nil collection.last_synced_at
    assert_equal 'ready', collection.sync_status
    assert collection.last_synced_at > 30.seconds.ago
  end

  test "should set last_synced_at when collection has no projects" do
    collection = @user.collections.create!(
      name: "Empty Collection",
      github_organization_url: "https://github.com/empty-org"
    )
    
    # Initially, collection should not have last_synced_at set
    assert_nil collection.last_synced_at
    
    # Check sync status with no projects
    collection.check_and_update_sync_status
    
    # Collection should have last_synced_at set even with no projects
    collection.reload
    assert_not_nil collection.last_synced_at
    assert_equal 'ready', collection.sync_status
    assert collection.last_synced_at > 30.seconds.ago
  end
end
