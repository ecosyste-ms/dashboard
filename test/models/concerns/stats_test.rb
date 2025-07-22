require "test_helper"

class StatsTest < ActiveSupport::TestCase
  setup do
    @collective = create(:collective)
    @project = create(:project, collective: @collective)
    
    # Create some test issues
    @issue1 = create(:issue, 
      project: @project, 
      created_at: 5.days.ago,
      user: "alice"
    )
    
    @pr1 = create(:issue, :pull_request,
      project: @project, 
      created_at: 3.days.ago,
      merged_at: 2.days.ago,
      user: "bob"
    )
    
    @closed_issue = create(:issue, :closed, :with_time_to_close,
      project: @project, 
      created_at: 7.days.ago,
      closed_at: 4.days.ago,
      time_to_close: 3.days.to_i,
      user: "charlie"
    )

    # Create some commits
    @commit1 = create(:commit,
      project: @project,
      timestamp: 4.days.ago,
      author: "alice",
      committer: "alice",
      additions: 10,
      deletions: 5
    )

    # Create some transactions
    @transaction1 = create(:transaction,
      collective_id: @collective.id,
      amount: 100,
      created_at: 6.days.ago,
      transaction_kind: "CONTRIBUTION"
    )
  end

  test "new_issues_count returns count and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.new_issues_count(
      collective_slugs: @collective.slug, 
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # Should find at least our issue
    assert_equal 0, result[1]
  end

  test "new_pull_requests_count returns count and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.new_pull_requests_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # Should find at least our PR
    assert_equal 0, result[1]
  end

  test "closed_issues_count returns count and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.closed_issues_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # Should find at least our closed issue
    assert_equal 0, result[1]
  end

  test "merged_pull_requests_count returns count and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.merged_pull_requests_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # Should find at least our merged PR
    assert_equal 0, result[1]
  end

  test "open_issues returns current and last period counts" do
    result = @collective.class.open_issues(
      collective_slugs: @collective.slug,
      range: 7
    )
    
    assert_equal 2, result.length
    assert result[0] >= 0
    assert result[1] >= 0
  end

  test "open_pull_requests returns current and last period counts" do
    result = @collective.class.open_pull_requests(
      collective_slugs: @collective.slug,
      range: 7
    )
    
    assert_equal 2, result.length
    assert result[0] >= 0
    assert result[1] >= 0
  end

  test "issue_authors_count returns distinct author count and zero" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.issue_authors_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # alice and charlie
    assert_equal 0, result[1]
  end

  test "pull_request_authors_count returns distinct author count and zero" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.pull_request_authors_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # bob
    assert_equal 0, result[1]
  end

  test "avg_issue_time_to_close returns average and zero" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.avg_issue_time_to_close(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert_equal 0, result[1]
  end

  test "avg_pr_time_to_merge returns average and zero" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.avg_pr_time_to_merge(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert_equal 0, result[1]
  end

  test "issues_scope with collective_slugs filters by collective" do
    other_collective = create(:collective)
    other_project = create(:project, collective: other_collective)
    create(:issue, project: other_project)
    
    issues = @collective.class.issues_scope(collective_slugs: @collective.slug)
    
    # Should only include issues from our collective's projects
    project_ids = @collective.projects.pluck(:id)
    issues.each do |issue|
      assert_includes project_ids, issue.project_id
    end
  end

  test "issues_scope with project_ids filters by project" do
    other_project = create(:project)
    create(:issue, project: other_project)
    
    issues = @collective.class.issues_scope(project_ids: @project.id.to_s)
    
    issues.each do |issue|
      assert_equal @project.id, issue.project_id
    end
  end

  test "commits_count returns count and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.commits_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # Should find our commit
    assert_equal 0, result[1]
  end

  test "commit_authors_count returns distinct author count and zero" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.commit_authors_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 1  # alice
    assert_equal 0, result[1]
  end

  test "additions_count returns sum and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.additions_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 10  # Our commit had 10 additions
    assert_equal 0, result[1]
  end

  test "deletions_count returns sum and zero for period" do
    start_date = 10.days.ago
    end_date = 1.day.ago
    
    result = @collective.class.deletions_count(
      collective_slugs: @collective.slug,
      start_date: start_date, 
      end_date: end_date
    )
    
    assert_equal 2, result.length
    assert result[0] >= 5  # Our commit had 5 deletions
    assert_equal 0, result[1]
  end
end