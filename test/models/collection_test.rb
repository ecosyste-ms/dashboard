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
    
    
    # Perform the import
    collection.import_from_dependency_file
    
    # Verify projects were created
    assert collection.projects.count > 0
    
    rails_project = collection.projects.find_by(url: "https://github.com/rails/rails")
    lodash_project = collection.projects.find_by(url: "https://github.com/lodash/lodash")
    
    assert rails_project, "Rails project should be imported"
    assert lodash_project, "Lodash project should be imported"
  end

  test "should validate dependency file format" do
    collection = build(:collection, 
      github_organization_url: nil,
      collective_url: nil,
      github_repo_url: nil,
      dependency_file: "invalid json content",
      user: @user
    )
    assert_not collection.valid?
    assert_includes collection.errors[:dependency_file], "must be a valid JSON SBOM file"
  end

  test "should accept valid JSON in dependency file" do
    valid_json = { "bomFormat" => "CycloneDX", "components" => [] }.to_json
    collection = build(:collection,
      github_organization_url: nil,
      collective_url: nil, 
      github_repo_url: nil,
      dependency_file: valid_json,
      user: @user
    )
    assert collection.valid?
    assert_empty collection.errors[:dependency_file]
  end

  test "should handle invalid SBOM JSON gracefully during import" do
    # Create a collection with valid JSON initially, then test import error handling
    valid_json = { "bomFormat" => "CycloneDX", "components" => [] }.to_json
    collection = @user.collections.create!(
      name: "SBOM Collection",
      dependency_file: valid_json
    )
    
    # Simulate corrupted file content during import by stubbing JSON.parse to raise an error
    JSON.stubs(:parse).raises(JSON::ParserError.new("test error")).then.returns({})
    
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
    stub_request(:get, "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/testorg1/repositories?per_page=10&page=1")
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

  # Integration tests with real API responses
  test "import collection from GitHub organization" do
    VCR.use_cassette("collection_sync/github_org_basic") do
      collection = create(:collection, 
        name: "Rails Organization",
        github_organization_url: "https://github.com/rails",
        user: @user
      )
      
      initial_project_count = collection.projects.count
      
      collection.import_projects_sync
      collection.reload
      
      assert_equal 'completed', collection.import_status
      assert collection.projects.count > initial_project_count
      
      # Verify we got actual Rails org projects
      assert collection.projects.any? { |p| p.url.include?('github.com/rails/') }
    end
  end

  test "import collection from Open Collective" do
    VCR.use_cassette("collection_sync/opencollective_basic") do
      collection = create(:collection,
        name: "Test Open Collective",
        collective_url: "https://opencollective.com/webpack",
        user: @user
      )
      
      collection.import_projects_sync
      collection.reload
      
      assert_equal 'completed', collection.import_status
      assert collection.projects.count > 0
    end
  end

  # Test collection import with mocked APIs (fast)
  test "import collection from GitHub org with mocked API" do
    collection = create(:collection,
      name: "Test Org",
      github_organization_url: "https://github.com/testorg",
      user: @user
    )
    
    # Mock the GitHub org API response - first page with data, then empty pages
    stub_request(:get, "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/testorg/repositories?page=1&per_page=10")
      .to_return(status: 200, body: [
        { "html_url" => "https://github.com/testorg/repo1" },
        { "html_url" => "https://github.com/testorg/repo2" }
      ].to_json)
    
    # Mock empty responses for subsequent pages to stop pagination
    (2..10).each do |page|
      stub_request(:get, "https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/testorg/repositories?page=#{page}&per_page=10")
        .to_return(status: 200, body: [].to_json)
    end
    
    collection.import_projects_sync
    collection.reload
    
    assert_equal 'completed', collection.import_status
    assert_equal 2, collection.projects.count
    assert collection.projects.find_by(url: "https://github.com/testorg/repo1")
    assert collection.projects.find_by(url: "https://github.com/testorg/repo2")
  end

  test "sync_least_recently_synced should queue collections for syncing" do
    old_collection = create(:collection, import_status: 'completed', last_synced_at: 2.days.ago)
    new_collection = create(:collection, import_status: 'completed', last_synced_at: 1.day.ago)
    never_synced = create(:collection, import_status: 'completed', last_synced_at: nil)
    importing_collection = create(:collection, import_status: 'importing')

    assert_difference 'SyncCollectionWorker.jobs.size', 4 do
      Collection.sync_least_recently_synced(10)
    end

    jobs = SyncCollectionWorker.jobs
    synced_collection_ids = jobs.map { |job| job['args'][0] }
    
    assert_includes synced_collection_ids, never_synced.id
    assert_includes synced_collection_ids, old_collection.id
    assert_includes synced_collection_ids, new_collection.id
    assert_includes synced_collection_ids, importing_collection.id
  end

  test "sync_least_recently_synced should respect limit parameter" do
    15.times do |i|
      create(:collection, last_synced_at: i.days.ago)
    end

    assert_difference 'SyncCollectionWorker.jobs.size', 5 do
      Collection.sync_least_recently_synced(5)
    end
  end


  test "sync_eligible scope should include all collections" do
    completed1 = create(:collection, import_status: 'completed')
    completed2 = create(:collection, import_status: 'completed')
    importing = create(:collection, import_status: 'importing')
    error = create(:collection, import_status: 'error')

    eligible_collections = Collection.sync_eligible

    assert_includes eligible_collections, completed1
    assert_includes eligible_collections, completed2
    assert_includes eligible_collections, importing
    assert_includes eligible_collections, error
  end

  test "sync_stuck? returns true for syncing collection with old updated_at" do
    collection = create(:collection, sync_status: 'syncing', updated_at: 1.hour.ago)
    assert collection.sync_stuck?
  end

  test "sync_stuck? returns false for syncing collection with recent updated_at" do
    collection = create(:collection, sync_status: 'syncing', updated_at: 15.minutes.ago)
    assert_not collection.sync_stuck?
  end

  test "sync_stuck? returns false for ready collection" do
    collection = create(:collection, sync_status: 'ready', updated_at: 1.hour.ago)
    assert_not collection.sync_stuck?
  end

  test "sync_stuck? returns false for pending collection" do
    collection = create(:collection, sync_status: 'pending', updated_at: 1.hour.ago)
    assert_not collection.sync_stuck?
  end

  test "dependency counts are deduplicated across projects" do
    collection = create(:collection)
    
    # Create first project with:
    # - react: direct runtime
    # - lodash: transitive runtime  
    # - jest: direct development (both direct AND development)
    project1 = build(:project,
      url: "https://github.com/test/project1",
      dependencies: [{
        'dependencies' => [
          {'package_name' => 'react', 'direct' => true, 'kind' => 'runtime'},
          {'package_name' => 'lodash', 'direct' => false, 'kind' => 'runtime'},
          {'package_name' => 'jest', 'direct' => true, 'kind' => 'development'}
        ]
      }],
      direct_dependencies_count: 2, # react, jest
      development_dependencies_count: 1, # jest  
      transitive_dependencies_count: 1 # lodash
    )
    project1.save!
    
    # Create second project with:
    # - react: direct runtime (duplicate with project1)
    # - express: direct runtime
    # - webpack: direct development (both direct AND development)
    project2 = build(:project,
      url: "https://github.com/test/project2",
      dependencies: [{
        'dependencies' => [
          {'package_name' => 'react', 'direct' => true, 'kind' => 'runtime'}, # duplicate
          {'package_name' => 'express', 'direct' => true, 'kind' => 'runtime'},
          {'package_name' => 'webpack', 'direct' => true, 'kind' => 'development'}
        ]
      }],
      direct_dependencies_count: 3, # react, express, webpack
      development_dependencies_count: 1, # webpack
      transitive_dependencies_count: 0
    )
    project2.save!
    
    # Add projects to collection
    collection.collection_projects.create!(project: project1)
    collection.collection_projects.create!(project: project2)
    
    # Test that summing project counts would give wrong answer (double counting)
    sum_direct = collection.projects.sum(:direct_dependencies_count)
    sum_development = collection.projects.sum(:development_dependencies_count)
    sum_transitive = collection.projects.sum(:transitive_dependencies_count)
    
    assert_equal 5, sum_direct # Would be 5 (2+3) with double counting react
    assert_equal 2, sum_development # Would be 2 (1+1)
    assert_equal 1, sum_transitive # Would be 1 (1+0)
    
    # Test that our new methods properly deduplicate
    collection.recalculate_dependency_counts!
    
    assert_equal 4, collection.direct_dependencies_count # react, jest, express, webpack (react deduplicated)
    assert_equal 2, collection.development_dependencies_count # jest, webpack
    assert_equal 1, collection.transitive_dependencies_count # lodash
    
    # Test that the dependency arrays are also properly deduplicated
    assert_equal 4, collection.direct_dependencies.length
    assert_equal 2, collection.development_dependencies.length  
    assert_equal 1, collection.transitive_dependencies.length
    
    # Test that cached values are used
    assert_equal 4, collection[:direct_dependencies_count]
    assert_equal 2, collection[:development_dependencies_count]
    assert_equal 1, collection[:transitive_dependencies_count]
  end

  test "collections should only show active projects" do
    collection = create(:collection)
    project1 = create(:project, url: "https://github.com/test/project1")
    project2 = create(:project, url: "https://github.com/test/project2")
    
    # Create collection_projects
    cp1 = collection.collection_projects.create!(project: project1)
    cp2 = collection.collection_projects.create!(project: project2)
    
    assert_equal 2, collection.projects.count
    assert_includes collection.projects, project1
    assert_includes collection.projects, project2
    
    # Soft delete one collection_project
    cp1.soft_delete!
    collection.reload
    
    assert_equal 1, collection.projects.count
    assert_not_includes collection.projects, project1
    assert_includes collection.projects, project2
    
    # Restore the soft-deleted collection_project
    cp1.restore!
    collection.reload
    
    assert_equal 2, collection.projects.count
    assert_includes collection.projects, project1
    assert_includes collection.projects, project2
  end

  test "add_project_to_collection should work with collections" do
    collection = create(:collection)
    project = create(:project)
    
    assert_difference 'collection.projects.count', 1 do
      CollectionProject.add_project_to_collection(collection, project)
    end
    
    assert_includes collection.projects, project
    
    # Adding the same project again should not create a duplicate
    assert_no_difference 'collection.projects.count' do
      CollectionProject.add_project_to_collection(collection, project)
    end
    
    # Soft delete the collection_project and add again - should restore
    cp = collection.collection_projects.find_by(project: project)
    cp.soft_delete!
    collection.reload
    assert_not_includes collection.projects, project
    
    assert_no_difference 'CollectionProject.count' do
      CollectionProject.add_project_to_collection(collection, project)
    end
    
    collection.reload
    assert_includes collection.projects, project
  end

  test "collection import methods should restore soft deleted projects" do
    collection = create(:collection)
    project = create(:project, url: "https://github.com/test/existing")
    
    # Create and then soft delete a collection_project
    cp = collection.collection_projects.create!(project: project)
    cp.soft_delete!
    collection.reload
    assert_not_includes collection.projects, project
    assert_equal 0, collection.projects.count
    
    # Use add_project_to_collection which should restore the soft-deleted record
    result = CollectionProject.add_project_to_collection(collection, project)
    
    collection.reload
    assert_includes collection.projects, project
    assert_equal 1, collection.projects.count
    assert result.active?
    assert_equal cp, result # Should be the same record, just restored
  end

  test "unique_collective_ids returns unique collective IDs from projects" do
    collection = create(:collection)
    
    # Create collective records
    collective1 = create(:collective)
    collective2 = create(:collective)
    
    # Create projects with collective_ids
    project1 = create(:project, url: "https://github.com/test/project1", collective_id: collective1.id)
    project2 = create(:project, url: "https://github.com/test/project2", collective_id: collective2.id)
    project3 = create(:project, url: "https://github.com/test/project3", collective_id: collective1.id) # duplicate collective
    project4 = create(:project, url: "https://github.com/test/project4", collective_id: nil) # no collective
    
    # Add projects to collection
    collection.collection_projects.create!(project: project1)
    collection.collection_projects.create!(project: project2)
    collection.collection_projects.create!(project: project3)
    collection.collection_projects.create!(project: project4)
    
    # Test unique_collective_ids method
    collective_ids = collection.unique_collective_ids
    
    # Should return unique collective IDs, excluding nil
    assert_equal 2, collective_ids.length
    assert_includes collective_ids, collective1.id
    assert_includes collective_ids, collective2.id
    assert_not_includes collective_ids, nil
  end

  test "unique_collective_ids returns empty array when no projects have collectives" do
    collection = create(:collection)
    
    # Create projects without collective_ids
    project1 = create(:project, url: "https://github.com/test/project1", collective_id: nil)
    project2 = create(:project, url: "https://github.com/test/project2", collective_id: nil)
    
    collection.collection_projects.create!(project: project1)
    collection.collection_projects.create!(project: project2)
    
    collective_ids = collection.unique_collective_ids
    
    assert_equal [], collective_ids
  end

  test "unique_collective_ids returns empty array when collection has no projects" do
    collection = create(:collection)
    
    collective_ids = collection.unique_collective_ids
    
    assert_equal [], collective_ids
  end
end
