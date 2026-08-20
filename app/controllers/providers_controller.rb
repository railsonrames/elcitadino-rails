class ProvidersController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]

  def index
    @provider_profiles = ProviderProfile.includes(:user)
    @provider_profiles = @provider_profiles.where(category: params[:category]) if params[:category].present?

    if params[:q].present?
      term = "%#{params[:q]}%"
      @provider_profiles = @provider_profiles.joins(:user)
        .where("users.name ILIKE :q OR provider_profiles.bio ILIKE :q OR provider_profiles.city ILIKE :q", q: term)
    end
  end

  def show
    @provider_profile = ProviderProfile.find(params[:id])
    @services = @provider_profile.services
  end
end
