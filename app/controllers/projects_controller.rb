class ProjectsController < ApplicationController
  before_action :set_period_vars, only: [:engagement, :productivity, :finance, :responsiveness, :security]
  before_action :authenticate_user!, only: [:index, :new, :create, :add_to_list, :remove_from_list, :create_collection_from_dependencies]
  before_action :set_collection, if: :nested_route?
  before_action :redirect_if_syncing, only: [:show, :adoption, :engagement, :dependencies, :productivity, :finance, :responsiveness, :packages, :commits, :releases, :issues, :advisories, :security]

  def show
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
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
    @user_projects = current_user.user_projects.active.includes(:project)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.find_by(url: project_params[:url].downcase)
    
    if @project.present?
      # Project already exists, add it to user's list
      UserProject.add_project_to_user(current_user, @project)
      redirect_to @project, notice: 'Project added to your list.'
    else
      # Create new project
      @project = Project.new(url: project_params[:url].downcase)
      
      if @project.save
        # Add project to user's list
        UserProject.add_project_to_user(current_user, @project)
        
        @project.broadcast_sync_update  # Initial broadcast for newly created project
        @project.sync_async
        redirect_to @project, notice: 'Project was successfully created and added to your list.'
      else
        render :new
      end
    end
  end

  def lookup
    # Handle both url and purl parameters
    if params[:purl].present?
      lookup_by_purl
    elsif params[:url].present?
      lookup_by_url
    else
      redirect_to root_path, alert: "Please provide either a URL or PURL parameter"
    end
  end

  def lookup_by_url
    url = params[:url].downcase
    
    # First try exact URL match
    @project = Project.find_by(url: url)
    
    # If not found, try homepage_url match
    if @project.nil?
      @project = Project.joins(:packages).where("packages.metadata ->> 'homepage' = ?", params[:url]).first ||
                 Project.where("repository ->> 'homepage' = ?", params[:url]).first
    end
    
    # If still not found, try package registry URL to purl conversion
    purl_obj = nil
    if @project.nil?
      begin
        purl_obj = Purl.from_registry_url(params[:url])
        if purl_obj
          # Remove version from purl since packages table stores purl without version
          purl_without_version = purl_obj.with(version: nil).to_s
          @project = Package.find_by(purl: purl_without_version)&.project
        end
      rescue => e
        # Ignore purl conversion errors and continue
        Rails.logger.debug "Could not convert URL to purl: #{e.message}"
      end
    end
    
    handle_project_result(purl_obj, params[:url])
  end

  def lookup_by_purl
    begin
      purl_obj = Purl.parse(params[:purl])
      
      # Try to find project by purl (without version)
      purl_without_version = purl_obj.with(version: nil).to_s
      @project = Package.find_by(purl: purl_without_version)&.project
      
      handle_project_result(purl_obj, params[:purl])
    rescue => e
      Rails.logger.debug "Could not parse purl: #{e.message}"
      redirect_to new_project_path(url: params[:purl])
    end
  end

  def handle_project_result(purl_obj, original_param)
    if @project.nil?
      # If we have a valid purl but didn't find project, try to resolve repository URL
      if purl_obj
        repository_url = resolve_repository_url_from_purl(purl_obj)
        
        if repository_url
          # Create project directly and start syncing
          project = Project.find_or_create_by(url: repository_url.downcase)
          project.sync_async if project.persisted?
          redirect_to project
        else
          # Project doesn't exist and couldn't resolve repository URL
          # For PURL parameters, show an error instead of invalid URL
          if original_param.start_with?('pkg:')
            flash[:error] = "Package not found: Could not locate or resolve the repository for '#{purl_obj.name}' (#{purl_obj.type}). The package may not exist in our database or external registries."
            redirect_to root_path
          else
            # For regular URLs, redirect with original param
            redirect_to new_project_path(url: original_param)
          end
        end
      else
        # Not a package URL/purl, redirect with original param
        redirect_to new_project_path(url: original_param)
      end
    else
      # Project exists, redirect to it
      redirect_to @project
    end
  end

  def packages
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @pagy, @packages = pagy(@project.packages.active.order_by_rankings)
  end

  def commits
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @pagy, @commits = pagy(@project.commits.order('timestamp DESC'))
  end

  def releases
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @pagy, @releases = pagy(@project.tags.displayable.order('published_at DESC'))
  end

  def issues
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @pagy, @issues = pagy(@project.issues.order('created_at DESC'))
  end

  def advisories
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @pagy, @advisories = pagy(@project.advisories.order('published_at DESC'))
  end

  def security
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])

    # Date filtering using period ranges from set_period_vars
    advisories_scope = @project.advisories
    dependabot_scope = @project.issues.dependabot.security_prs

    # Apply period filtering - use this_period_range for filtering data to current period
    advisories_scope = advisories_scope.where(published_at: @this_period_range)
    dependabot_scope = dependabot_scope.where(created_at: @this_period_range)

    @pagy, @advisories = pagy(advisories_scope.order('published_at DESC'))

    # Dependabot security data
    @dependabot_security_issues = @project.issues.dependabot.security_prs
    @dependabot_security_count = @dependabot_security_issues.count
    @dependabot_open_security = @dependabot_security_issues.open.count
    @dependabot_closed_security = @dependabot_security_issues.closed.count
    @dependabot_filtered_count = dependabot_scope.count

    # Time series data for chart
    if @range == 'year'
      @dependabot_security_per_period = dependabot_scope.group_by_year(:created_at, format: '%Y', last: 6, expand_range: true, default_value: 0).count
      @advisories_per_period = advisories_scope.group_by_year(:published_at, format: '%Y', last: 6, expand_range: true, default_value: 0).count
    else
      @dependabot_security_per_period = dependabot_scope.group_by_month(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
      @advisories_per_period = advisories_scope.group_by_month(:published_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    end

    @recent_dependabot_security = dependabot_scope.order('created_at DESC').limit(5)
  end

  def adoption
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    @top_package = @project.packages.order_by_rankings.first
  end

  def engagement
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])

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
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    # Calculate unique counts for filter buttons (to match table display)
    @direct_dependencies = @project.direct_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }.length
    @development_dependencies = @project.development_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }.length
    @transitive_dependencies = @project.transitive_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }.length
    
    # Get filtered dependencies based on params
    @filtered_dependencies = case params[:filter]
    when 'direct'
      @project.direct_dependencies
    when 'development'
      @project.development_dependencies
    when 'transitive'
      @project.transitive_dependencies
    else
      @project.direct_dependencies + @project.development_dependencies + @project.transitive_dependencies
    end
    
    # Remove duplicates by package name while preserving first occurrence
    @unique_dependencies = @filtered_dependencies.uniq { |dep| dep['package_name'] || dep['name'] }
  end

  def productivity
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    
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
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])

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
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])

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
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    begin
      @project.sync
      flash[:notice] = 'Project synced'
    rescue => e
      flash[:alert] = "Sync failed: #{e.message}"
    end
    redirect_to project_path(@project)
  end

  def meta
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
  end

  def add_to_list
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    UserProject.add_project_to_user(current_user, @project)
    redirect_back(fallback_location: @project, notice: 'Project added to your list.')
  end

  def syncing
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    
    if @project.sync_stuck?
      @project.update_column(:sync_status, 'completed')
      @project.sync_async
      redirect_to @project, notice: 'Project is now accessible. Sync continues in background.'
      return
    end
    
    unless @project.never_synced?
      redirect_to @project
      return
    end
    
    @project.sync_async if @project.sync_status != 'syncing'
  end


  def remove_from_list
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    user_project = UserProject.find_by(user: current_user, project: @project)
    if user_project
      user_project.soft_delete!
      redirect_to projects_path, notice: 'Project removed from your list.'
    else
      redirect_to projects_path, alert: 'Project not found in your list.'
    end
  end

  def create_collection_from_dependencies
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    
    collection = @project.create_collection_from_dependencies(current_user)
    
    if collection
      redirect_to collection, notice: 'Collection created successfully from project dependencies!'
    else
      redirect_to dependencies_project_path(@project), alert: 'Unable to create collection. This project may not have any dependencies.'
    end
  end

  def owner_collection
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    
    # Check if we can find an existing public collection without needing to authenticate
    existing_collection = find_existing_owner_collection
    Rails.logger.debug "Existing collection found: #{existing_collection.present?}"
    
    if existing_collection
      redirect_to existing_collection, notice: "Viewing #{existing_collection.name} collection!"
      return
    end
    
    # If no existing collection found, require login to create one
    unless logged_in?
      redirect_to login_path, alert: 'Please sign in to create collections.'
      return
    end
    
    collection = @project.find_or_create_owner_collection(current_user)
    
    if collection
      # Start syncing the collection if it was just created
      collection.sync_projects if collection.projects.empty?
      redirect_to collection, notice: "Viewing #{collection.name} collection!"
    else
      redirect_to @project, alert: 'Unable to create owner collection. This project may not have repository owner information.'
    end
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
    @project = Project.find_by_slug(params[:id]) || Project.find(params[:id])
    
    if @project.sync_stuck?
      @project.update_column(:sync_status, 'completed')
      @project.sync_async
    end
    
    if @project.never_synced?
      @project.sync_async if @project.sync_status != 'syncing'
      render :syncing
    end
  end

  def project_params
    params.require(:project).permit(:url)
  end

  def find_existing_owner_collection
    @project.find_existing_owner_collection
  end

  def resolve_repository_url_from_purl(purl_obj)
    begin
      # Remove version for API lookup
      purl_without_version = purl_obj.with(version: nil).to_s
      
      # Call packages.ecosyste.ms API
      response = Faraday.get("https://packages.ecosyste.ms/api/v1/packages/lookup", { purl: purl_without_version })
      
      if response.success?
        data = JSON.parse(response.body)
        if data.is_a?(Array) && data.any?
          # Find the first result that has a repository_url field
          result = data.find { |item| item['repository_url'].present? }
          return result['repository_url'] if result
        end
      end
    rescue => e
      Rails.logger.debug "Failed to resolve repository URL from purl: #{e.message}"
    end
    
    nil
  end
end