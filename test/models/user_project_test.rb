require "test_helper"

class UserProjectTest < ActiveSupport::TestCase
  def setup
    @user = FactoryBot.create(:user)
    @project = FactoryBot.create(:project, :with_repository)
  end

  test "should create user project with valid attributes" do
    user_project = UserProject.new(user: @user, project: @project)
    assert user_project.valid?
  end

  test "should require user" do
    user_project = UserProject.new(project: @project)
    assert_not user_project.valid?
    assert_includes user_project.errors[:user], "must exist"
  end

  test "should require project" do
    user_project = UserProject.new(user: @user)
    assert_not user_project.valid?
    assert_includes user_project.errors[:project], "must exist"
  end

  test "should not allow duplicate user project combinations" do
    UserProject.create!(user: @user, project: @project)
    duplicate = UserProject.new(user: @user, project: @project)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "should have default values" do
    user_project = UserProject.create!(user: @user, project: @project)
    assert_nil user_project.deleted_at
    assert user_project.active?
  end

  test "add_project_to_user should create new user project" do
    assert_difference "UserProject.count", 1 do
      UserProject.add_project_to_user(@user, @project)
    end
  end

  test "add_project_to_user should not create duplicate" do
    UserProject.create!(user: @user, project: @project)
    assert_no_difference "UserProject.count" do
      UserProject.add_project_to_user(@user, @project)
    end
  end

  test "add_project_to_user should create active project" do
    user_project = UserProject.add_project_to_user(@user, @project)
    assert user_project.active?
  end

  test "add_project_to_user should restore soft deleted project" do
    user_project = UserProject.create!(user: @user, project: @project)
    user_project.soft_delete!
    assert user_project.deleted?
    
    # Adding same project should restore it
    restored_project = UserProject.add_project_to_user(@user, @project)
    assert_equal user_project, restored_project
    assert restored_project.active?
  end

  test "soft_delete! should set deleted_at" do
    user_project = UserProject.create!(user: @user, project: @project)
    user_project.soft_delete!
    assert user_project.deleted?
    assert_not_nil user_project.deleted_at
  end

  test "restore! should clear deleted_at" do
    user_project = UserProject.create!(user: @user, project: @project)
    user_project.soft_delete!
    user_project.restore!
    assert user_project.active?
    assert_nil user_project.deleted_at
  end

  test "active scope should return only non-deleted records" do
    active_project = UserProject.create!(user: @user, project: @project)
    other_project = FactoryBot.create(:project, :with_repository)
    deleted_project = UserProject.create!(user: @user, project: other_project)
    deleted_project.soft_delete!
    
    assert_includes UserProject.active, active_project
    assert_not_includes UserProject.active, deleted_project
  end

  test "deleted scope should return only deleted records" do
    active_project = UserProject.create!(user: @user, project: @project)
    other_project = FactoryBot.create(:project, :with_repository)
    deleted_project = UserProject.create!(user: @user, project: other_project)
    deleted_project.soft_delete!
    
    assert_includes UserProject.deleted, deleted_project
    assert_not_includes UserProject.deleted, active_project
  end

end