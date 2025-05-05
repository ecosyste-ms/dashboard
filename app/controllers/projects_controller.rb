class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
    @range = range
    @period = period
    etag_data = [@project, @range, @period]
    fresh_when(etag: etag_data, public: true)
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
      sort = params[:sort].presence || 'updated_at'
      if params[:order] == 'asc'
        @scope = @scope.order(Arel.sql(sort).asc.nulls_last)
      else
        @scope = @scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      @scope = @scope.order_by_stars
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
  end

  def engagement
    @project = Project.find(params[:id])
  end

  def dependency
    @project = Project.find(params[:id])
  end

  def productivity
    @project = Project.find(params[:id])
    @range = range
    @period = period
    
    @commits_last_period = @project.commits.last_period(@range).count
    @commits_this_period = @project.commits.this_period(@range).count

    @tags_last_period = @project.tags.last_period(@range).count
    @tags_this_period = @project.tags.this_period(@range).count

    commits_last = @project.commits.last_period(@range)
    commits_this = @project.commits.this_period(@range)

    authors_last = commits_last.select(:author).distinct.count
    authors_this = commits_this.select(:author).distinct.count

    @avg_commits_per_author_last_period = authors_last.zero? ? 0 : (commits_last.count.to_f / authors_last).round(1)
    @avg_commits_per_author_this_period = authors_this.zero? ? 0 : (commits_this.count.to_f / authors_this).round(1)

    @new_issues_last_period = @project.issues.issue.last_period(@range).count
    @new_issues_this_period = @project.issues.issue.this_period(@range).count

    @open_isues_last_period = @project.issues.issue.open_last_period(@range).count
    @open_isues_this_period = @project.issues.issue.open_this_period(@range).count

    @advisories_last_period = @project.advisories.last_period(@range).count
    @advisories_this_period = @project.advisories.this_period(@range).count

    @new_prs_last_period = @project.issues.pull_request.last_period(@range).count
    @new_prs_this_period = @project.issues.pull_request.this_period(@range).count

    @open_prs_last_period = @project.issues.pull_request.open_last_period(@range).count
    @open_prs_this_period = @project.issues.pull_request.open_this_period(@range).count

    @merged_prs_last_period = @project.issues.pull_request.merged_last_period(@range).count
    @merged_prs_this_period = @project.issues.pull_request.merged_this_period(@range).count
  end

  def finance
    @project = Project.find(params[:id])
  end

  def responsiveness
    @project = Project.find(params[:id])
  end

  def sync
    @project = Project.find(params[:id])
    @project.sync
    flash[:notice] = 'Project synced'
    redirect_to project_path(@project)
  end
end