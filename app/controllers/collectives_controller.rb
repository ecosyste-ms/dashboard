class CollectivesController < ApplicationController
  def index
    scope = Collective.opensource

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'updated_at'
      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      scope = scope.order('balance desc nulls last')
    end
    
    @period = period
    @range = range
    @interval = interval
    @end_date = 1.month.ago.end_of_month
    @start_date = 1.year.ago

    @pagy, @collectives = pagy(scope)
    fresh_when(@collectives, public: true)
  end

  def batch
    @slugs = params[:collective_slugs].try(:split, ',') || params[:slugs].try(:split, ',')
    raise ActiveRecord::RecordNotFound if @slugs.nil? || @slugs.empty?
    @collectives = Collective.opensource.where(slug: @slugs).limit(20)

    @range = range
    @period = period
    @start_date = start_date
    @end_date = end_date

    projects_scope = Project.joins(:collective).where('collectives.id in (?)', @collectives.pluck(:id))

    @pagy, @projects = pagy(projects_scope.order_by_stars)
    @transactions = Transaction.where(collective_id: @collectives.pluck(:id)).created_after(@start_date).any?
  end

  def show
    @collective = Collective.find_by_slug!(params[:id])
    @range = range
    @period = period
    @start_date = start_date
    @end_date = end_date
    @interval = interval
    
    etag_data = [@collective, @range, @period, @start_date, @end_date, @interval]
    fresh_when(etag: etag_data, public: true)
  end

  def funders
    @collective = Collective.find_by_slug!(params[:id])
    @funders = @collective.funders
  end

  def projects
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @projects = pagy(@collective.projects_with_repository.active.source.order_by_stars)
  end

  def packages
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @packages = pagy(@collective.packages.includes(:project).active)
  end

  def issues
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @issues = pagy(@collective.issues.includes(:project).order('created_at DESC'))
  end

  def releases
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @releases = pagy(@collective.tags.displayable.includes(:project).order('published_at DESC'))
  end

  def commits
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @commits = pagy(@collective.commits.includes(:project).order('timestamp DESC'))
  end

  def advisories
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @advisories = pagy(@collective.advisories.includes(:project).order('published_at DESC'))
  end

  def transactions
    @collective = Collective.find_by_slug!(params[:id])
    @pagy, @transactions = pagy(@collective.transactions.order('created_at DESC'))
  end

  def charts
    @collectives_by_total_donations = Collective.opensource.where('total_donations > 0').order('total_donations DESC').pluck(:slug, :total_donations)

    @top_50_collectives_by_total_donations = @collectives_by_total_donations.first(50)


    # load critical packages with funding links
    
    @critical_packages = load_critical_packages
  
    ecosystem_counts = @critical_packages.each_with_object(Hash.new(0)) { |pkg, counts| counts[pkg['ecosystem']] += 1 }

    # Sort ecosystems by frequency (most frequent first)
    @ecosystems = ecosystem_counts.sort_by { |_, count| -count }.map(&:first)
  

    

  end

  private

  def load_critical_packages
    Rails.cache.fetch('critical_packages', expires_in: 1.hour) do
      critical_packages = []
      page = 1

      loop do
        url = "https://packages.ecosyste.ms/api/v1/packages/critical?funding=true&per_page=1000&page=#{page}"
        response = Faraday.get url
        data = JSON.parse(response.body)
        break if data.empty?
        data.each do |package|
          critical_packages << package if package['funding_links'].any?{|link| link.include?('opencollective.com') } && !%w[docker puppet].include?(package['ecosystem'])
        end
        page += 1
      end

      critical_packages
    end
  end
end