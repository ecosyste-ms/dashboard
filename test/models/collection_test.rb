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
    collection = @user.collections.build(dependency_file: @cyclone_dx_sbom)
    json = JSON.parse(@cyclone_dx_sbom)
    
    purls = collection.extract_purls_from_sbom(json)
    
    expected_purls = [
      "pkg:gem/rails@7.0.0",
      "pkg:npm/react@18.0.0", 
      "pkg:github/rails/rails@v7.0.0"
    ]
    
    assert_equal expected_purls, purls
  end

  test "should extract PURLs from SPDX SBOM" do
    collection = @user.collections.build(dependency_file: @spdx_sbom)
    json = JSON.parse(@spdx_sbom)
    
    purls = collection.extract_purls_from_sbom(json)
    
    expected_purls = [
      "pkg:gem/activerecord@7.0.0",
      "pkg:npm/lodash@4.17.21"
    ]
    
    assert_equal expected_purls, purls
  end
end
