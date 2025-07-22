require "test_helper"

class IssueTest < ActiveSupport::TestCase
  test "belongs to project" do
    project = create(:project)
    issue = Issue.new(project: project)
    assert_equal project, issue.project
  end

  test "to_param returns number as string" do
    issue = Issue.new(number: 123)
    assert_equal "123", issue.to_param
  end

  test "scope label filters by labels" do
    issue1 = create(:issue, labels: ["bug", "feature"])
    issue2 = create(:issue, labels: ["enhancement"])
    issue3 = create(:issue, labels: ["bug"])

    results = Issue.label(["bug"])
    assert_includes results, issue1
    assert_includes results, issue3
    assert_not_includes results, issue2
  end

  test "scope past_year filters issues from past year" do
    old_issue = create(:issue, created_at: 2.years.ago)
    recent_issue = create(:issue, created_at: 6.months.ago)

    results = Issue.past_year
    assert_includes results, recent_issue
    assert_not_includes results, old_issue
  end

  test "scope bot filters bot users" do
    bot_issue = create(:issue, :bot_user)
    human_issue = create(:issue, user: "alice")

    results = Issue.bot
    assert_includes results, bot_issue
    assert_not_includes results, human_issue
  end

  test "scope human filters human users" do
    bot_issue = create(:issue, :bot_user)
    human_issue = create(:issue, user: "alice")

    results = Issue.human
    assert_includes results, human_issue
    assert_not_includes results, bot_issue
  end

  test "scope merged filters merged pull requests" do
    merged_pr = create(:issue, :merged)
    closed_pr = create(:issue, :pull_request, :closed)

    results = Issue.merged
    assert_includes results, merged_pr
    assert_not_includes results, closed_pr
  end

  test "scope not_merged filters closed but not merged pull requests" do
    merged_pr = create(:issue, :merged)
    closed_pr = create(:issue, :pull_request, :closed)

    results = Issue.not_merged
    assert_includes results, closed_pr
    assert_not_includes results, merged_pr
  end

  test "scope open filters open issues" do
    open_issue = create(:issue)
    closed_issue = create(:issue, :closed)

    results = Issue.open
    assert_includes results, open_issue
    assert_not_includes results, closed_issue
  end

  test "scope closed filters closed issues" do
    open_issue = create(:issue)
    closed_issue = create(:issue, :closed)

    results = Issue.closed
    assert_includes results, closed_issue
    assert_not_includes results, open_issue
  end

  test "scope pull_request filters pull requests" do
    issue = create(:issue)
    pr = create(:issue, :pull_request)

    results = Issue.pull_request
    assert_includes results, pr
    assert_not_includes results, issue
  end

  test "scope issue filters issues (not pull requests)" do
    issue = create(:issue)
    pr = create(:issue, :pull_request)

    results = Issue.issue
    assert_includes results, issue
    assert_not_includes results, pr
  end

  test "scope maintainers filters by maintainer associations" do
    owner_issue = create(:issue, author_association: "OWNER")
    member_issue = create(:issue, author_association: "MEMBER")
    collaborator_issue = create(:issue, author_association: "COLLABORATOR")
    none_issue = create(:issue, author_association: "NONE")

    results = Issue.maintainers
    assert_includes results, owner_issue
    assert_includes results, member_issue
    assert_includes results, collaborator_issue
    assert_not_includes results, none_issue
  end

  test "scope this_period filters issues created in period" do
    recent_issue = create(:issue, created_at: 5.days.ago)
    old_issue = create(:issue, created_at: 15.days.ago)

    results = Issue.this_period(7)
    assert_includes results, recent_issue
    assert_not_includes results, old_issue
  end

  test "scope between filters issues created between dates" do
    start_date = 10.days.ago
    end_date = 5.days.ago
    
    in_range_issue = create(:issue, created_at: 7.days.ago)
    before_range_issue = create(:issue, created_at: 15.days.ago)
    after_range_issue = create(:issue, created_at: 2.days.ago)

    results = Issue.between(start_date, end_date)
    assert_includes results, in_range_issue
    assert_not_includes results, before_range_issue
    assert_not_includes results, after_range_issue
  end
end