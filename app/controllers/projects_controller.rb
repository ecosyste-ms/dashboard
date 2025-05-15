class ProjectsController < ApplicationController
  before_action :set_period_vars, only: [:engagement, :productivity, :finance, :responsiveness]

  def show
    @project = Project.find(params[:id])
    @range = range
    @period = period
    etag_data = [@project, @range, @period]
    fresh_when(etag: etag_data, public: true)
    @top_package = @project.packages.order_by_rankings.first
  end

  def index
    @scope = Project.with_repository.active

    if params[:keyword].present?
      @scope = @scope.keyword(params[:keyword])
    end

    if params[:owner].present?
      @scope = @scope.owner(params[:owner])
    end

    if params[:language].present?
      @scope = @scope.language(params[:language])
    end

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'created_at'
      if params[:order] == 'asc'
        @scope = @scope.order(Arel.sql(sort).asc.nulls_last)
      else
        @scope = @scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      @scope = @scope.order('created_at DESC')
    end

    @pagy, @projects = pagy(@scope)
    fresh_when(@projects, public: true)
  end

  def lookup
    @project = Project.find_by(url: params[:url].downcase)
    if @project.nil?
      @project = Project.create!(url: params[:url].downcase)
      @project.sync_async
    end
    redirect_to @project
  end

  def packages
    @project = Project.find(params[:id])
    @pagy, @packages = pagy(@project.packages.active.order_by_rankings)
  end

  def commits
    @project = Project.find(params[:id])
    @pagy, @commits = pagy(@project.commits.order('timestamp DESC'))
    fresh_when(@commits, public: true)
  end

  def releases
    @project = Project.find(params[:id])
    @pagy, @releases = pagy(@project.tags.displayable.order('published_at DESC'))
    fresh_when(@releases, public: true)
  end

  def issues
    @project = Project.find(params[:id])
    @pagy, @issues = pagy(@project.issues.order('created_at DESC'))
    fresh_when(@issues, public: true)
  end

  def advisories
    @project = Project.find(params[:id])
    @pagy, @advisories = pagy(@project.advisories.order('published_at DESC'))
    fresh_when(@advisories, public: true)
  end

  def adoption
    @project = Project.find(params[:id])
    @top_package = @project.packages.order_by_rankings.first
  end

  def engagement
    @project = Project.find(params[:id])

    @range = range
    @period = period

    @active_contributors_last_period = @project.issues.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @active_contributors_this_period = @project.issues.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributions_last_period = @project.issues.between(@last_period_range.begin, @last_period_range.end).count
    @contributions_this_period = @project.issues.between(@this_period_range.begin, @this_period_range.end).count

    @issue_authors_last_period = @project.issues.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @issue_authors_this_period = @project.issues.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @pr_authors_last_period = @project.issues.pull_request.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @pr_authors_this_period = @project.issues.pull_request.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributor_role_breakdown_this_period = @project.issues.between(@this_period_range.begin, @this_period_range.end).group(:author_association).count.sort_by { |_role, count| -count }.to_h

    @all_time_contributors = @project.issues.group(:user).count.length

    if period == :year
      @contributions_per_period = @project.issues.group_by_year(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    else
      @contributions_per_period = @project.issues.group_by_month(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    end
  end

  def dependency
    @project = Project.find(params[:id])
    @direct_dependencies = @project.direct_dependencies.length
    @development_dependencies = @project.development_dependencies.length
    @transitive_dependencies = @project.transitive_dependencies.length
  end

  def productivity
    @project = Project.find(params[:id])
    
    @commits_last_period = @project.commits.between(@last_period_range.begin, @last_period_range.end).count
    @commits_this_period = @project.commits.between(@this_period_range.begin, @this_period_range.end).count

    @tags_last_period = @project.tags.between(@last_period_range.begin, @last_period_range.end).count
    @tags_this_period = @project.tags.between(@this_period_range.begin, @this_period_range.end).count

    commits_last = @project.commits.between(@last_period_range.begin, @last_period_range.end)
    commits_this = @project.commits.between(@this_period_range.begin, @this_period_range.end)

    authors_last = commits_last.select(:author).distinct.count
    authors_this = commits_this.select(:author).distinct.count

    @avg_commits_per_author_last_period = authors_last.zero? ? 0 : (commits_last.count.to_f / authors_last).round(1)
    @avg_commits_per_author_this_period = authors_this.zero? ? 0 : (commits_this.count.to_f / authors_this).round(1)

    @new_issues_last_period = @project.issues.issue.between(@last_period_range.begin, @last_period_range.end).count
    @new_issues_this_period = @project.issues.issue.between(@this_period_range.begin, @this_period_range.end).count

    @open_isues_last_period = @project.issues.issue.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_isues_this_period = @project.issues.issue.open_between(@this_period_range.begin, @this_period_range.end).count

    @advisories_last_period = @project.advisories.between(@last_period_range.begin, @last_period_range.end).count
    @advisories_this_period = @project.advisories.between(@this_period_range.begin, @this_period_range.end).count

    @new_prs_last_period = @project.issues.pull_request.between(@last_period_range.begin, @last_period_range.end).count
    @new_prs_this_period = @project.issues.pull_request.between(@this_period_range.begin, @this_period_range.end).count

    @open_prs_last_period = @project.issues.pull_request.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_prs_this_period = @project.issues.pull_request.open_between(@this_period_range.begin, @this_period_range.end).count

    @merged_prs_last_period = @project.issues.pull_request.merged_between(@last_period_range.begin, @last_period_range.end).count
    @merged_prs_this_period = @project.issues.pull_request.merged_between(@this_period_range.begin, @this_period_range.end).count
  end

  def finance
    @project = Project.find(params[:id])

    if @project.collective.present?

      @contributions_last_period = @project.collective.transactions.donations.between(@last_period_range.begin, @last_period_range.end).count
      @contributions_this_period = @project.collective.transactions.donations.between(@this_period_range.begin, @this_period_range.end).count

      @payments_last_period = @project.collective.transactions.expenses.between(@last_period_range.begin, @last_period_range.end).count
      @payments_this_period = @project.collective.transactions.expenses.between(@this_period_range.begin, @this_period_range.end).count

      @balance_last_period = 0 # TODO: Fix this
      @balance_this_period = 0 # TODO: Fix this

      @donors_last_period =  @project.collective.transactions.donations.between(@last_period_range.begin, @last_period_range.end).group(:from_account).count.length
      @donors_this_period =  @project.collective.transactions.donations.between(@this_period_range.begin, @this_period_range.end).group(:from_account).count.length

      @payees_last_period = @project.collective.transactions.expenses.between(@last_period_range.begin, @last_period_range.end).group(:to_account).count.length
      @payees_this_period = @project.collective.transactions.expenses.between(@this_period_range.begin, @this_period_range.end).group(:to_account).count.length
    end
  end

  def responsiveness
    @project = Project.find(params[:id])

    @time_to_close_prs_last_period = (@project.issues.pull_request.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - created_at))') || 0) / 86400.0
    @time_to_close_prs_last_period = @time_to_close_prs_last_period.round(1)

    @time_to_close_prs_this_period = (@project.issues.pull_request.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - created_at))') || 0) / 86400.0
    @time_to_close_prs_this_period = @time_to_close_prs_this_period.round(1)

    @time_to_close_issues_last_period = (@project.issues.issue.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - created_at))') || 0) / 86400.0
    @time_to_close_issues_last_period = @time_to_close_issues_last_period.round(1)

    @time_to_close_issues_this_period = (@project.issues.issue.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - created_at))') || 0) / 86400.0
    @time_to_close_issues_this_period = @time_to_close_issues_this_period.round(1)
  end

  def sync
    @project = Project.find(params[:id])
    @project.sync
    flash[:notice] = 'Project synced'
    redirect_to project_path(@project)
  end

  def meta
    @project = Project.find(params[:id])
  end

  private

  def set_period_vars
    @range = range
    @year = year
    @month = month
    @period_date = period_date

    @this_period_range =
      if @range == 'year'
        @period_date.beginning_of_year..@period_date.end_of_year
      else
        @period_date.beginning_of_month..@period_date.end_of_month
      end

    @last_period_range =
      if @range == 'year'
        (@period_date - 1.year).beginning_of_year..(@period_date - 1.year).end_of_year
      else
        (@period_date - 1.month).beginning_of_month..(@period_date - 1.month).end_of_month
      end
  end

  def range
    params[:range].in?(%w[month year]) ? params[:range] : 'month'
  end

  def year
    (params[:year] || Time.current.year).to_i
  end

  def month
    range == 'month' ? (params[:month] || Time.current.month).to_i : nil
  end

  def period_date
    return Date.new(year) if range == 'year'
    Date.new(year, month)
  end
end