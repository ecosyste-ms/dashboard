class AdvisoriesController < ApplicationController
  def index
    @advisories = Advisory.order('published_at DESC').includes(:project)
    @pagy, @advisories = pagy(@advisories)
  end
end
