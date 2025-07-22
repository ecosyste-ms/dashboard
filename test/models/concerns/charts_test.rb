require "test_helper"

class ChartsTest < ActiveSupport::TestCase
  setup do
    @collective = create(:collective)
    @project = create(:project, collective: @collective)
    
    # Create test transactions
    @transaction1 = create(:transaction,
      collective_id: @collective.id,
      amount: 100,
      net_amount: 100,
      created_at: 5.days.ago,
      transaction_kind: "CONTRIBUTION",
      account: "alice"
    )
    
    @expense1 = create(:transaction, :expense,
      collective_id: @collective.id,
      created_at: 3.days.ago,
      account: "bob"
    )

    # Create test issues
    @issue1 = create(:issue, :closed, :with_time_to_close,
      project: @project,
      created_at: 4.days.ago,
      closed_at: 2.days.ago,
      time_to_close: 2.days.to_i,
      user: "alice"
    )
    
    @pr1 = create(:issue, :merged,
      project: @project,
      created_at: 6.days.ago,
      merged_at: 3.days.ago,
      time_to_close: 3.days.to_i,
      user: "bob"
    )

    # Create test commits
    @commit1 = create(:commit,
      project: @project,
      timestamp: 5.days.ago,
      author: "alice",
      committer: "alice",
      additions: 100,
      deletions: 50
    )

    # Create test tags
    @tag1 = create(:tag,
      project: @project,
      name: "v1.0.0",
      published_at: 4.days.ago
    )
  end

  test "transaction_chart_data with all_transactions kind" do
    scope = @collective.transactions
    
    result = @collective.class.transaction_chart_data(
      scope, 
      kind: 'all_transactions',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "transaction_chart_data with expenses kind" do
    scope = @collective.transactions
    
    result = @collective.class.transaction_chart_data(
      scope,
      kind: 'expenses',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "transaction_chart_data with donations kind" do
    scope = @collective.transactions
    
    result = @collective.class.transaction_chart_data(
      scope,
      kind: 'donations',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "transaction_chart_data with donor_pie kind" do
    scope = @collective.transactions
    
    result = @collective.class.transaction_chart_data(
      scope,
      kind: 'donor_pie',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "issue_chart_data with issues_opened kind" do
    scope = @collective.issues
    
    result = @collective.class.issue_chart_data(
      scope,
      kind: 'issues_opened',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "issue_chart_data with issues_closed kind" do
    scope = @collective.issues
    
    result = @collective.class.issue_chart_data(
      scope,
      kind: 'issues_closed',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "issue_chart_data with pull_requests_opened kind" do
    scope = @collective.issues
    
    result = @collective.class.issue_chart_data(
      scope,
      kind: 'pull_requests_opened',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "issue_chart_data with pull_requests_merged kind" do
    scope = @collective.issues
    
    result = @collective.class.issue_chart_data(
      scope,
      kind: 'pull_requests_merged',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "issue_chart_data with issue_authors kind" do
    scope = @collective.issues
    
    result = @collective.class.issue_chart_data(
      scope,
      kind: 'issue_authors',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "commit_chart_data with commits kind" do
    scope = @collective.commits
    
    result = @collective.class.commit_chart_data(
      scope,
      kind: 'commits',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "commit_chart_data with commit_authors kind" do
    scope = @collective.commits
    
    result = @collective.class.commit_chart_data(
      scope,
      kind: 'commit_authors',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end

  test "commit_chart_data with changes_pie kind" do
    scope = @collective.commits
    
    result = @collective.class.commit_chart_data(
      scope,
      kind: 'changes_pie',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
    assert_equal 100, result['Additions']
    assert_equal 50, result['Deletions']
  end

  test "tag_chart_data with tags kind" do
    scope = @collective.tags
    
    result = @collective.class.tag_chart_data(
      scope,
      kind: 'tags',
      period: :day,
      range: 7,
      start_date: 10.days.ago,
      end_date: 1.day.ago
    )
    
    assert result.is_a?(Hash)
  end
end