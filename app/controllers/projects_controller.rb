class ProjectsController < ApplicationController
  before_action :set_period_vars, only: [:engagement, :productivity, :finance, :responsiveness]
  before_action :authenticate_user!, only: [:new, :create]
  before_action :set_collection, if: :nested_route?
  before_action :redirect_if_syncing, only: [:show, :adoption, :engagement, :dependencies, :productivity, :finance, :responsiveness, :packages, :commits, :releases, :issues, :advisories]

  def show
    @project = Project.find(params[:id])
    @range = range
    @period = period
    
    # Generate dynamic commit data for the chart
    if @range.to_i <= 180  # 6 months or less
      @commits_per_period = @project.commits.group_by_month(:timestamp, format: '%b', last: 6, expand_range: true, default_value: 0).count
    else
      @commits_per_period = @project.commits.group_by_year(:timestamp, format: '%Y', last: 6, expand_range: true, default_value: 0).count
    end
    
    # Calculate current and previous period commits
    current_period_start = @range.to_i.days.ago
    previous_period_start = (@range.to_i * 2).days.ago
    
    @commits_this_period = @project.commits.where('timestamp >= ?', current_period_start).count
    @commits_last_period = @project.commits.where('timestamp >= ? AND timestamp < ?', previous_period_start, current_period_start).count
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
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.find_by(url: project_params[:url].downcase)
    
    if @project.present?
      # Project already exists, redirect to it
      redirect_to @project, notice: 'Project already exists in the system.'
    else
      # Create new project
      @project = Project.new(url: project_params[:url].downcase)
      
      if @project.save
        @project.broadcast_sync_update  # Initial broadcast for newly created project
        @project.sync_async
        redirect_to @project, notice: 'Project was successfully created and is now syncing.'
      else
        render :new
      end
    end
  end

  def lookup
    @project = Project.find_by(url: params[:url].downcase)
    if @project.nil?
      # Project doesn't exist, redirect to new project form with the URL pre-filled
      redirect_to new_project_path(url: params[:url])
    else
      # Project exists, redirect to it
      redirect_to @project
    end
  end

  def packages
    @project = Project.find(params[:id])
    @pagy, @packages = pagy(@project.packages.active.order_by_rankings)
  end

  def commits
    @project = Project.find(params[:id])
    @pagy, @commits = pagy(@project.commits.order('timestamp DESC'))
  end

  def releases
    @project = Project.find(params[:id])
    @pagy, @releases = pagy(@project.tags.displayable.order('published_at DESC'))
  end

  def issues
    @project = Project.find(params[:id])
    @pagy, @issues = pagy(@project.issues.order('created_at DESC'))
  end

  def advisories
    @project = Project.find(params[:id])
    @pagy, @advisories = pagy(@project.advisories.order('published_at DESC'))
  end

  def adoption
    @project = Project.find(params[:id])
    @top_package = @project.packages.order_by_rankings.first
  end

  def engagement
    @project = Project.find(params[:id])

    # Apply bot filtering based on params
    issues_scope = @project.issues
    issues_scope = issues_scope.human if params[:exclude_bots] == 'true'
    issues_scope = issues_scope.bot if params[:only_bots] == 'true'

    @active_contributors_last_period = issues_scope.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @active_contributors_this_period = issues_scope.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributions_last_period = issues_scope.between(@last_period_range.begin, @last_period_range.end).count
    @contributions_this_period = issues_scope.between(@this_period_range.begin, @this_period_range.end).count

    @issue_authors_last_period = issues_scope.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @issue_authors_this_period = issues_scope.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @pr_authors_last_period = issues_scope.pull_request.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @pr_authors_this_period = issues_scope.pull_request.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributor_role_breakdown_this_period = issues_scope.between(@this_period_range.begin, @this_period_range.end).group(:author_association).count.sort_by { |_role, count| -count }.to_h

    @all_time_contributors = issues_scope.group(:user).count.length

    if @range == 'year'
      @contributions_per_period = issues_scope.group_by_year(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    else
      @contributions_per_period = issues_scope.group_by_month(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    end
  end

  def dependencies
    @project = Project.find(params[:id])
    @direct_dependencies = @project.direct_dependencies.length
    @development_dependencies = @project.development_dependencies.length
    @transitive_dependencies = @project.transitive_dependencies.length
  end

  def productivity
    @project = Project.find(params[:id])
    
    # Apply bot filtering based on params
    issues_scope = @project.issues
    issues_scope = issues_scope.human if params[:exclude_bots] == 'true'
    issues_scope = issues_scope.bot if params[:only_bots] == 'true'

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

    @new_issues_last_period = issues_scope.issue.between(@last_period_range.begin, @last_period_range.end).count
    @new_issues_this_period = issues_scope.issue.between(@this_period_range.begin, @this_period_range.end).count

    @open_isues_last_period = issues_scope.issue.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_isues_this_period = issues_scope.issue.open_between(@this_period_range.begin, @this_period_range.end).count

    @advisories_last_period = @project.advisories.between(@last_period_range.begin, @last_period_range.end).count
    @advisories_this_period = @project.advisories.between(@this_period_range.begin, @this_period_range.end).count

    @new_prs_last_period = issues_scope.pull_request.between(@last_period_range.begin, @last_period_range.end).count
    @new_prs_this_period = issues_scope.pull_request.between(@this_period_range.begin, @this_period_range.end).count

    @open_prs_last_period = issues_scope.pull_request.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_prs_this_period = issues_scope.pull_request.open_between(@this_period_range.begin, @this_period_range.end).count

    @merged_prs_last_period = issues_scope.pull_request.merged_between(@last_period_range.begin, @last_period_range.end).count
    @merged_prs_this_period = issues_scope.pull_request.merged_between(@this_period_range.begin, @this_period_range.end).count
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

    if @project.github_sponsors.present?
      @current_sponsors = @project.current_github_sponsors_count
      @total_sponsors = @project.total_github_sponsors_count
      @past_sponsors = @project.past_github_sponsors_count
    end
  end

  def responsiveness
    @project = Project.find(params[:id])

    # Apply bot filtering based on params
    issues_scope = @project.issues
    issues_scope = issues_scope.human if params[:exclude_bots] == 'true'
    issues_scope = issues_scope.bot if params[:only_bots] == 'true'

    @time_to_close_prs_last_period = (issues_scope.pull_request.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_last_period = @time_to_close_prs_last_period.round(1)

    @time_to_close_prs_this_period = (issues_scope.pull_request.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_this_period = @time_to_close_prs_this_period.round(1)

    @time_to_close_issues_last_period = (issues_scope.issue.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_last_period = @time_to_close_issues_last_period.round(1)

    @time_to_close_issues_this_period = (issues_scope.issue.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_this_period = @time_to_close_issues_this_period.round(1)
  end

  def sync
    @project = Project.find(params[:id])
    begin
      @project.sync
      flash[:notice] = 'Project synced'
    rescue => e
      flash[:alert] = "Sync failed: #{e.message}"
    end
    redirect_to project_path(@project)
  end

  def meta
    @project = Project.find(params[:id])
  end

  def syncing
    @project = Project.find(params[:id])
  end

  private

  def nested_route?
    params[:collection_id].present?
  end

  def set_collection
    @collection = Collection.find_by_uuid(params[:collection_id])
    raise ActiveRecord::RecordNotFound if @collection.nil?
    if @collection.visibility == 'private' && @collection.user != current_user
      raise ActiveRecord::RecordNotFound
    end
  end

  def set_period_vars
    @range = range
    @year = year
    @month = month
    @period_date = period_date
    @previous_year = @range == 'year' ? (params[:previous_year] || @year - 1).to_i : (params[:previous_year] || @year).to_i
    
    if @month
      previous_month_value = (params[:previous_month] || @month - 1).to_i
      if previous_month_value <= 0
        @previous_month = 12
        @previous_year = @previous_year - 1
      else
        @previous_month = previous_month_value
      end
    else
      @previous_month = nil
    end

    @this_period_range =
      if @range == 'year'
        @period_date.beginning_of_year..@period_date.end_of_year
      else
        @period_date.beginning_of_month..@period_date.end_of_month
      end

    @last_period_range =
      if @range == 'year'
        Date.new(@previous_year).beginning_of_year..Date.new(@previous_year).end_of_year
      else
        Date.new(@previous_year, @previous_month).beginning_of_month..Date.new(@previous_year, @previous_month).end_of_month
      end
  end

  def range
    params[:range].in?(%w[month year]) ? params[:range] : 'month'
  end

  def year
    (params[:year] || 1.month.ago.year).to_i
  end

  def month
    range == 'month' ? (params[:month] || 1.month.ago.month).to_i : nil
  end

  def period_date
    return Date.new(year) if range == 'year'
    Date.new(year, month)
  end

  def redirect_if_syncing
    @project = Project.find(params[:id])
    render :syncing unless @project.ready?
  end

  def project_params
    params.require(:project).permit(:url)
  end
end