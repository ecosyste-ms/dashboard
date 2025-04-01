class Api::V1::CollectivesController < Api::V1::ApplicationController
  def index
    @collectives = Collective.opensource
    @pagy, @collectives = pagy(@collectives)
  end

  def show
    @collective = Collective.find_by_slug!(params[:id])
  end
end