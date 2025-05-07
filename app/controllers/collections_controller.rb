class CollectionsController < ApplicationController
  def index
    scope = Collection.all
    @pagy, @collections = pagy(scope)
  end

  def show
    @collection = Collection.find(params[:id])
    @range = range
    @period = period
    etag_data = [@collection, @range, @period]
    fresh_when(etag: etag_data, public: true)
    # @top_package = @collection.packages.order_by_rankings.first
  end

  def adoption
    @collection = Collection.find(params[:id])
    @top_package = @collection.packages.order_by_rankings.first
  end

  def engagement
    @collection = Collection.find(params[:id])

    @range = range
    @period = period

    @active_contributors_last_period = @collection.issues.last_period(@range).group(:user).count.length
    @active_contributors_this_period = @collection.issues.this_period(@range).group(:user).count.length

    @contributions_last_period = @collection.issues.last_period(@range).count
    @contributions_this_period = @collection.issues.this_period(@range).count

    @issue_authors_last_period = @collection.issues.last_period(@range).group(:user).count.length
    @issue_authors_this_period = @collection.issues.this_period(@range).group(:user).count.length

    @pr_authors_last_period = @collection.issues.pull_request.last_period(@range).group(:user).count.length
    @pr_authors_this_period = @collection.issues.pull_request.this_period(@range).group(:user).count.length

    @contributor_role_breakdown_this_period = @collection.issues.this_period(@range).group(:author_association).count.sort_by { |_role, count| -count }.to_h

    @all_time_contributors = @collection.issues.group(:user).count.length

    if period == :year
      @contributions_per_period = @collection.issues.group_by_year(:created_at, format: '%Y-%m', last: 6, expand_range: true, default_value: 0).count
    else
      @contributions_per_period = @collection.issues.group_by_month(:created_at, format: '%Y-%m', last: 6, expand_range: true, default_value: 0).count
    end
  end

  def dependency
    @collection = Collection.find(params[:id])
    @direct_dependencies = @collection.direct_dependencies.length
    @development_dependencies = @collection.development_dependencies.length
    @transitive_dependencies = @collection.transitive_dependencies.length
  end

  def productivity
    @collection = Collection.find(params[:id])
    @range = range
    @period = period
    
    @commits_last_period = @collection.commits.last_period(@range).count
    @commits_this_period = @collection.commits.this_period(@range).count

    @tags_last_period = @collection.tags.last_period(@range).count
    @tags_this_period = @collection.tags.this_period(@range).count

    commits_last = @collection.commits.last_period(@range)
    commits_this = @collection.commits.this_period(@range)

    authors_last = commits_last.select(:author).distinct.count
    authors_this = commits_this.select(:author).distinct.count

    @avg_commits_per_author_last_period = authors_last.zero? ? 0 : (commits_last.count.to_f / authors_last).round(1)
    @avg_commits_per_author_this_period = authors_this.zero? ? 0 : (commits_this.count.to_f / authors_this).round(1)

    @new_issues_last_period = @collection.issues.issue.last_period(@range).count
    @new_issues_this_period = @collection.issues.issue.this_period(@range).count

    @open_isues_last_period = @collection.issues.issue.open_last_period(@range).count
    @open_isues_this_period = @collection.issues.issue.open_this_period(@range).count

    @advisories_last_period = @collection.advisories.last_period(@range).count
    @advisories_this_period = @collection.advisories.this_period(@range).count

    @new_prs_last_period = @collection.issues.pull_request.last_period(@range).count
    @new_prs_this_period = @collection.issues.pull_request.this_period(@range).count

    @open_prs_last_period = @collection.issues.pull_request.open_last_period(@range).count
    @open_prs_this_period = @collection.issues.pull_request.open_this_period(@range).count

    @merged_prs_last_period = @collection.issues.pull_request.merged_last_period(@range).count
    @merged_prs_this_period = @collection.issues.pull_request.merged_this_period(@range).count
  end

  def finance
    @collection = Collection.find(params[:id])

    @range = range
    @period = period

    if @collection.collective.present?

      @contributions_last_period = @collection.collective.transactions.donations.last_period(@range).count
      @contributions_this_period = @collection.collective.transactions.donations.this_period(@range).count

      @payments_last_period = @collection.collective.transactions.expenses.last_period(@range).count
      @payments_this_period = @collection.collective.transactions.expenses.this_period(@range).count

      @balance_last_period = 0 # TODO: Fix this
      @balance_this_period = 0 # TODO: Fix this

      @donors_last_period =  @collection.collective.transactions.donations.last_period(@range).group(:from_account).count.length
      @donors_this_period =  @collection.collective.transactions.donations.this_period(@range).group(:from_account).count.length

      @payees_last_period = @collection.collective.transactions.expenses.last_period(@range).group(:to_account).count.length
      @payees_this_period = @collection.collective.transactions.expenses.this_period(@range).group(:to_account).count.length
    end
  end

  def responsiveness
    @collection = Collection.find(params[:id])

    @range = range
    @period = period

    @time_to_close_prs_last_period = (@collection.issues.pull_request.closed_last_period(@range)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_last_period = @time_to_close_prs_last_period.round(1)

    @time_to_close_prs_this_period = (@collection.issues.pull_request.closed_this_period(@range)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_this_period = @time_to_close_prs_this_period.round(1)

    @time_to_close_issues_last_period = (@collection.issues.issue.closed_last_period(@range)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_last_period = @time_to_close_issues_last_period.round(1)

    @time_to_close_issues_this_period = (@collection.issues.issue.closed_this_period(@range)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_this_period = @time_to_close_issues_this_period.round(1)
  end
end
