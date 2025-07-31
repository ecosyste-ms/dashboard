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
    assert_equal "active", user_project.status
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

  test "soft_delete! should set status to removed" do
    user_project = UserProject.create!(user: @user, project: @project)
    user_project.soft_delete!
    assert user_project.removed?
  end

  test "restore! should set status to active" do
    user_project = UserProject.create!(user: @user, project: @project, status: :removed)
    user_project.restore!
    assert user_project.active?
  end

end