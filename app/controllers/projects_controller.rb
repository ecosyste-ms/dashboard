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
      @project = Project.create(url: params[:url].downcase)
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
end