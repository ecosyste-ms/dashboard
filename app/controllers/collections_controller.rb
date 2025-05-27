class CollectionsController < ApplicationController
  before_action :set_period_vars, only: [:engagement, :productivity, :finance, :responsiveness]

  before_action :authenticate_user!

  def index
    scope = current_user.collections
    @pagy, @collections = pagy(scope)
  end

  def show
    @collection = current_user.collections.find_by_uuid(params[:id])
    @range = range
    @period = period
    @top_package = @collection.packages.order_by_rankings.first
  end

  def new
    @collection = current_user.collections.build
  end

  def create
    @collection = current_user.collections.build(collection_params)
    if @collection.save
      redirect_to @collection, notice: 'Collection was successfully created.'
    else
      render :new
    end
  end

  def edit
    @collection = current_user.collections.find_by_uuid(params[:id])
  end

  def update
    @collection = current_user.collections.find_by_uuid(params[:id])
    if @collection.update(collection_params)
      redirect_to @collection, notice: 'Collection was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @collection = current_user.collections.find_by_uuid(params[:id])
    @collection.destroy
    redirect_to collections_path, notice: 'Collection was successfully deleted.'
  end

  def adoption
    @collection = current_user.collections.find_by_uuid(params[:id])
    @top_package = @collection.packages.order_by_rankings.first
  end

  def engagement
    @collection = Collection.find_by_uuid(params[:id])
    
    @active_contributors_last_period = @collection.issues.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @active_contributors_this_period = @collection.issues.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributions_last_period = @collection.issues.between(@last_period_range.begin, @last_period_range.end).count
    @contributions_this_period = @collection.issues.between(@this_period_range.begin, @this_period_range.end).count

    @issue_authors_last_period = @collection.issues.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @issue_authors_this_period = @collection.issues.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @pr_authors_last_period = @collection.issues.pull_request.between(@last_period_range.begin, @last_period_range.end).group(:user).count.length
    @pr_authors_this_period = @collection.issues.pull_request.between(@this_period_range.begin, @this_period_range.end).group(:user).count.length

    @contributor_role_breakdown_this_period = @collection.issues.between(@this_period_range.begin, @this_period_range.end).group(:author_association).count.sort_by { |_role, count| -count }.to_h

    @all_time_contributors = @collection.issues.group(:user).count.length

    if @range == 'year'
      @contributions_per_period = @collection.issues.group_by_year(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    else
      @contributions_per_period = @collection.issues.group_by_month(:created_at, format: '%b %Y', last: 6, expand_range: true, default_value: 0).count
    end
  end

  def dependency
    @collection = current_user.collections.find_by_uuid(params[:id])
    @direct_dependencies = @collection.direct_dependencies.length
    @development_dependencies = @collection.development_dependencies.length
    @transitive_dependencies = @collection.transitive_dependencies.length
  end

  def productivity
    @collection = current_user.collections.find_by_uuid(params[:id])
    
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

    @new_issues_last_period = @collection.issues.issue.between(@last_period_range.begin, @last_period_range.end).count
    @new_issues_this_period = @collection.issues.issue.between(@this_period_range.begin, @this_period_range.end).count

    @open_isues_last_period = @collection.issues.issue.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_isues_this_period = @collection.issues.issue.open_between(@this_period_range.begin, @this_period_range.end).count

    @advisories_last_period = @collection.advisories.between(@last_period_range.begin, @last_period_range.end).count
    @advisories_this_period = @collection.advisories.between(@this_period_range.begin, @this_period_range.end).count

    @new_prs_last_period = @collection.issues.pull_request.between(@last_period_range.begin, @last_period_range.end).count
    @new_prs_this_period = @collection.issues.pull_request.between(@this_period_range.begin, @this_period_range.end).count

    @open_prs_last_period = @collection.issues.pull_request.open_between(@last_period_range.begin, @last_period_range.end).count
    @open_prs_this_period = @collection.issues.pull_request.open_between(@this_period_range.begin, @this_period_range.end).count

    @merged_prs_last_period = @collection.issues.pull_request.merged_between(@last_period_range.begin, @last_period_range.end).count
    @merged_prs_this_period = @collection.issues.pull_request.merged_between(@this_period_range.begin, @this_period_range.end).count
  end

  def finance
    @collection = current_user.collections.find_by_uuid(params[:id])

    if @collection.collective.present?

      @contributions_last_period = @collection.collective.transactions.donations.between(@last_period_range.begin, @last_period_range.end).count
      @contributions_this_period = @collection.collective.transactions.donations.between(@this_period_range.begin, @this_period_range.end).count

      @payments_last_period = @collection.collective.transactions.expenses.between(@last_period_range.begin, @last_period_range.end).count
      @payments_this_period = @collection.collective.transactions.expenses.between(@this_period_range.begin, @this_period_range.end).count

      @balance_last_period = 0 # TODO: Fix this
      @balance_this_period = 0 # TODO: Fix this

      @donors_last_period =  @collection.collective.transactions.donations.between(@last_period_range.begin, @last_period_range.end).group(:from_account).count.length
      @donors_this_period =  @collection.collective.transactions.donations.between(@this_period_range.begin, @this_period_range.end).group(:from_account).count.length

      @payees_last_period = @collection.collective.transactions.expenses.between(@last_period_range.begin, @last_period_range.end).group(:to_account).count.length
      @payees_this_period = @collection.collective.transactions.expenses.between(@this_period_range.begin, @this_period_range.end).group(:to_account).count.length
    end
  end

  def responsiveness
    @collection = current_user.collections.find_by_uuid(params[:id])

    @time_to_close_prs_last_period = (@collection.issues.pull_request.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_last_period = @time_to_close_prs_last_period.round(1)

    @time_to_close_prs_this_period = (@collection.issues.pull_request.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_prs_this_period = @time_to_close_prs_this_period.round(1)

    @time_to_close_issues_last_period = (@collection.issues.issue.closed_between(@last_period_range.begin, @last_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_last_period = @time_to_close_issues_last_period.round(1)

    @time_to_close_issues_this_period = (@collection.issues.issue.closed_between(@this_period_range.begin, @this_period_range.end)
      .average('EXTRACT(EPOCH FROM (closed_at - issues.created_at))') || 0) / 86400.0
    @time_to_close_issues_this_period = @time_to_close_issues_this_period.round(1)
  end

  def projects
    @collection = current_user.collections.find_by_uuid(params[:id])
    @projects = @collection.projects
    @pagy, @projects = pagy(@projects)
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :description, :url, :visibility)
  end

  def set_period_vars
    @range = range
    @year = year
    @month = month
    @period_date = period_date
    @previous_year = @range == 'year' ? (params[:previous_year] || @year - 1).to_i : (params[:previous_year] || @year).to_i
    @previous_month = @month ? (params[:previous_month] || @month - 1).to_i : nil

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
