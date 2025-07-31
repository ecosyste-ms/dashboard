require "test_helper"

class CollectionProjectTest < ActiveSupport::TestCase
  def setup
    @collection = create(:collection)
    @project = create(:project)
    @collection_project = create(:collection_project, collection: @collection, project: @project)
  end

  test "should belong to collection and project" do
    assert @collection_project.collection.present?
    assert @collection_project.project.present?
  end

  test "should validate uniqueness of collection_id scoped to project_id" do
    duplicate = build(:collection_project, collection: @collection, project: @project)
    assert_not duplicate.valid?
    assert duplicate.errors[:collection_id].present?
  end

  test "active scope should return only non-deleted records" do
    deleted_collection_project = create(:collection_project, :deleted)
    
    active_records = CollectionProject.active
    
    assert_includes active_records, @collection_project
    assert_not_includes active_records, deleted_collection_project
  end

  test "deleted scope should return only soft-deleted records" do
    deleted_collection_project = create(:collection_project, :deleted)
    
    deleted_records = CollectionProject.deleted
    
    assert_includes deleted_records, deleted_collection_project
    assert_not_includes deleted_records, @collection_project
  end

  test "soft_delete! should set deleted_at timestamp" do
    assert_nil @collection_project.deleted_at
    
    @collection_project.soft_delete!
    
    assert @collection_project.deleted_at.present?
    assert @collection_project.deleted?
  end

  test "restore! should clear deleted_at timestamp" do
    @collection_project.soft_delete!
    assert @collection_project.deleted?
    
    @collection_project.restore!
    
    assert_nil @collection_project.deleted_at
    assert @collection_project.active?
  end

  test "deleted? should return true when deleted_at is present" do
    assert_not @collection_project.deleted?
    
    @collection_project.soft_delete!
    
    assert @collection_project.deleted?
  end

  test "active? should return true when deleted_at is nil" do
    assert @collection_project.active?
    
    @collection_project.soft_delete!
    
    assert_not @collection_project.active?
  end

  test "add_project_to_collection should create new record when none exists" do
    new_collection = create(:collection)
    new_project = create(:project)
    
    assert_difference 'CollectionProject.count', 1 do
      result = CollectionProject.add_project_to_collection(new_collection, new_project)
      assert result.persisted?
      assert_equal new_collection, result.collection
      assert_equal new_project, result.project
      assert result.active?
    end
  end

  test "add_project_to_collection should return existing active record" do
    assert_no_difference 'CollectionProject.count' do
      result = CollectionProject.add_project_to_collection(@collection, @project)
      assert_equal @collection_project, result
      assert result.active?
    end
  end

  test "add_project_to_collection should restore soft-deleted record" do
    @collection_project.soft_delete!
    assert @collection_project.deleted?
    
    assert_no_difference 'CollectionProject.count' do
      result = CollectionProject.add_project_to_collection(@collection, @project)
      assert_equal @collection_project, result
      assert result.active?
    end
  end

  test "add_project_to_collection should handle restoration with flash message" do
    @collection_project.soft_delete!
    
    result = CollectionProject.add_project_to_collection(@collection, @project)
    
    @collection_project.reload
    assert @collection_project.active?
    assert_equal @collection_project, result
  end
end
