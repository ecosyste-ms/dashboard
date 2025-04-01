class SbomsController < ApplicationController
  def new
    @sbom = Sbom.new
  end

  def create
    @sbom = Sbom.new(sbom_params)
    if @sbom.save
      @sbom.convert
      redirect_to @sbom
    else
      render :new
    end
  end

  def index
    scope = Sbom.all
    @pagy, @sboms = pagy(scope)
  end

  def show
    @sbom = Sbom.find(params[:id])
  end

  private

  def sbom_params
    params.require(:sbom).permit(:raw)
  end
end
