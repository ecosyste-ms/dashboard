class CollectionsController < ApplicationController
  before_action :set_period_vars, only: [:engagement, :productivity, :finance, :responsiveness]

  before_action :authenticate_user!

  before_action :set_collection_with_visibility_check, except: [:index, :new, :create]
  before_action :redirect_if_syncing, only: [:show, :adoption, :engagement, :dependencies, :productivity, :finance, :responsiveness, :packages, :projects, :security]

  def index
    scope = current_user.collections
    @pagy, @collections = pagy(scope)
  end

  def show
    @range = range
    @period = period
    @top_package = @collection.packages.order_by_rankings.first
  end

  def syncing
    
  end

  def new
    @collection = current_user.collections.build
  end

  def create
    @collection = current_user.collections.build(collection_params)
    
    # Handle file upload for dependency_file
    if params[:collection][:dependency_file].respond_to?(:read)
      @collection.dependency_file = params[:collection][:dependency_file].read
    end
    
    if @collection.save
      # Trigger async import with ActionCable updates
      @collection.import_projects_async
      redirect_to @collection, notice: 'Collection was successfully created.'
    else
      flash.now[:alert] = @collection.errors.full_messages.to_sentence
      render :new
    end
  end

  def edit
    require_owner!
  end

  def update
    require_owner!
    
    # Handle file upload for dependency_file
    if params[:collection][:dependency_file].respond_to?(:read)
      params[:collection][:dependency_file] = params[:collection][:dependency_file].read
    end
    
    if @collection.update(collection_params)
      redirect_to @collection, notice: 'Collection was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    require_owner!
    @collection.destroy
    redirect_to collections_path, notice: 'Collection was successfully deleted.'
  end

  def adoption
    @top_package = @collection.packages.order_by_rankings.first
  end

  def engagement
    # Apply bot filtering based on params
    issues_scope = @collection.issues
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
    # Use cached dependency counts for performance
    @direct_dependencies = @collection.direct_dependencies_count
    @development_dependencies = @collection.development_dependencies_count  
    @transitive_dependencies = @collection.transitive_dependencies_count

    # Only load full dependency data if we need to display the table
    @direct_deps = @collection.direct_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }
    @development_deps = @collection.development_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }
    @transitive_deps = @collection.transitive_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }
    
    # Create lookup sets for faster type checking
    @direct_dep_names = Set.new(@direct_deps.map { |dep| dep['package_name'] || dep['name'] })
    @development_dep_names = Set.new(@development_deps.map { |dep| dep['package_name'] || dep['name'] })
    
    # Pre-calculate usage counts for performance
    @dependency_usage_counts = {}
    @collection.projects.each do |project|
      project.all_dependencies.each do |dep|
        package_name = dep['package_name'] || dep['name']
        @dependency_usage_counts[package_name] ||= 0
        @dependency_usage_counts[package_name] += 1
      end
    end
  end

  def productivity
    # Apply bot filtering based on params
    issues_scope = @collection.issues
    issues_scope = issues_scope.human if params[:exclude_bots] == 'true'
    issues_scope = issues_scope.bot if params[:only_bots] == 'true'

    @commits_last_period = @collection.commits.between(@last_period_range.begin, @last_period_range.end).count
    @commits_this_period = @collection.commits.between(@this_period_range.begin, @this_period_range.end).count

    @tags_last_period = @collection.tags.between(@last_period_range.begin, @last_period_range.end).count
    @tags_this_period = @collection.tags.between(@this_period_range.begin, @this_period_range.end).count

    commits_last = @collection.commits.between(@last_period_range.begin, @last_period_range.end)
    commits_this = @collection.commits.between(@this_period_range.begin, @this_period_range.end)

    authors_last = commits_last.select(:author).distinct.count
    authors_this = commits_this.select(:author).distinct.count

    @avg_commits_per_author_last_period = authors_last.zero? ? 0 : (commits_last.count.to_f / authors_last).round(1)
    @avg_commits_per_author_this_period = authors_this.zero? ? 0 : (commits_this.count.to_f / authors_this).round(1)

    @new_issues_last_period = issues_scope.issue.between(@last_period_range.begin, @last_period_range.end).count
    @new_issues_this_period = issues_scope.issue.between(@this_period_range.begin, @this_period_range.end).count

    @open_isues_last_period = issues_scope.issue.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_isues_this_period = issues_scope.issue.open_between(@this_period_range.begin, @this_period_range.end).count

    @advisories_last_period = @collection.advisories.between(@last_period_range.begin, @last_period_range.end).count
    @advisories_this_period = @collection.advisories.between(@this_period_range.begin, @this_period_range.end).count

    @new_prs_last_period = issues_scope.pull_request.between(@last_period_range.begin, @last_period_range.end).count
    @new_prs_this_period = issues_scope.pull_request.between(@this_period_range.begin, @this_period_range.end).count

    @open_prs_last_period = issues_scope.pull_request.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_prs_this_period = issues_scope.pull_request.open_between(@this_period_range.begin, @this_period_range.end).count

    @merged_prs_last_period = issues_scope.pull_request.merged_between(@last_period_range.begin, @last_period_range.end).count
    @merged_prs_this_period = issues_scope.pull_request.merged_between(@this_period_range.begin, @this_period_range.end).count
  end

  def finance
    # Calculate summary statistics
    projects_with_funding = @collection.projects.select { |p| 
      p.collective.present? || p.github_sponsors.present? || p.other_funding_links.present? 
    }
    
    @projects_with_funding_count = projects_with_funding.count
    @unique_collectives_count = @collection.projects.select(&:collective).map(&:collective_url).compact.uniq.count
    @unique_github_sponsors_count = @collection.projects.select { |p| p.github_sponsors.present? }.count
  end

  def responsiveness
    # Apply bot filtering based on params
    issues_scope = @collection.issues
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

  def packages
    @pagy, @packages = pagy(@collection.packages.active.order_by_rankings)
  end

  def security
    @pagy, @advisories = pagy(@collection.advisories.order('published_at DESC'))
  end

  def projects
    @projects = @collection.projects
    @pagy, @projects = pagy(@projects)
  end

  def sync
    # Clear any existing errors before starting new sync
    @collection.update(
      import_status: 'pending',
      sync_status: 'pending',
      last_error_message: nil,
      last_error_backtrace: nil,
      last_error_at: nil
    )
    
    @collection.import_projects_async
    flash[:notice] = 'Collection sync started'
    redirect_to collection_path(@collection)
  end

  private

  def collection_params
    params.require(:collection).permit(
      :name,
      :description,
      :url,
      :visibility,
      :github_organization_url,
      :collective_url,
      :github_repo_url,
      :dependency_file
    )
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

  def set_collection_with_visibility_check
    collection_id = params[:id] || params[:collection_id]
    @collection = Collection.includes(:projects).find_by_uuid(collection_id)
    raise ActiveRecord::RecordNotFound if @collection.nil?
    if @collection.visibility == 'private' && @collection.user != current_user
      raise ActiveRecord::RecordNotFound
    end
  end

  def require_owner!
    raise ActiveRecord::RecordNotFound unless @collection.user == current_user
  end

  def redirect_if_syncing
    # Restart stuck syncs
    if @collection.sync_stuck?
      Rails.logger.info "Restarting stuck sync for collection #{@collection.id}"
      @collection.import_projects_async
    end
    
    render :syncing unless @collection.ready?
  end
end
