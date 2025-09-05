require 'test_helper'

class Api::V1::CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    user = User.first || User.create!(email: 'test@example.com')
    
    # Find or create by github_organization_url to avoid conflicts and let slug auto-generate
    @public_collection = Collection.find_or_create_by(github_organization_url: 'https://github.com/rails-api-test') do |c|
      c.name = 'Public Collection'
      c.visibility = 'public'
      c.user = user
    end
    
    @private_collection = Collection.find_or_create_by(github_organization_url: 'https://github.com/private-org-test') do |c|
      c.name = 'Private Collection'
      c.visibility = 'private'
      c.user = user
    end
    
  end

  test 'should get index with only public collections' do
    get api_v1_collections_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    # Should include the public collection
    collection_ids = json_response.map { |c| c['id'] }
    assert_includes collection_ids, @public_collection.id
    # Should not include the private collection
    refute_includes collection_ids, @private_collection.id
  end

  test 'should show public collection' do
    get api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @public_collection.name, json_response['name']
    assert_equal @public_collection.slug, json_response['slug']
    assert_equal 'public', json_response['visibility']
  end

  test 'should not show private collection' do
    get api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should lookup public collection by slug' do
    get lookup_api_v1_collections_url(slug: @public_collection.slug), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal @public_collection.name, json_response['name']
  end

  test 'should not lookup private collection by slug' do
    get lookup_api_v1_collections_url(slug: @private_collection.slug), as: :json
    assert_response :not_found
  end

  test 'should get public collection projects' do
    get projects_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should not get private collection projects' do
    get projects_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should get public collection issues' do
    # Create test data
    project = create(:project, url: "https://github.com/test/collection-issues-#{SecureRandom.hex(8)}")
    @public_collection.projects << project
    create(:issue, project: project)
    
    get issues_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should get public collection releases' do
    # Create test data
    project = create(:project, url: "https://github.com/test/collection-releases-#{SecureRandom.hex(8)}")
    @public_collection.projects << project
    create(:tag, project: project)
    
    get releases_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should get public collection commits' do
    # Create test data
    project = create(:project, url: "https://github.com/test/collection-commits-#{SecureRandom.hex(8)}")
    @public_collection.projects << project
    create(:commit, project: project)
    
    get commits_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should get public collection packages' do
    # Create test data
    project = create(:project, url: "https://github.com/test/collection-packages-#{SecureRandom.hex(8)}")
    @public_collection.projects << project
    create(:package, project: project)
    
    get packages_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should get public collection advisories' do
    # Create test data
    project = create(:project, url: "https://github.com/test/collection-advisories-#{SecureRandom.hex(8)}")
    @public_collection.projects << project
    project.advisories.create!(
      uuid: SecureRandom.uuid,
      source_kind: 'test',
      title: 'Test Advisory',
      severity: 'high',
      published_at: 1.day.ago
    )
    
    get advisories_api_v1_collection_url(@public_collection), as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
  end

  test 'should not get private collection issues' do
    get issues_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should not get private collection releases' do
    get releases_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should not get private collection commits' do
    get commits_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should not get private collection packages' do
    get packages_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end

  test 'should not get private collection advisories' do
    get advisories_api_v1_collection_url(@private_collection), as: :json
    assert_response :not_found
  end
end