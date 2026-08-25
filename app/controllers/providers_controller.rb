class ProvidersController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show, :nearby ]

  def index
    @provider_profiles = ProviderProfile.where(listed: true).includes(:user)
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

  def nearby
    provider_profiles = ProviderProfile.near(params[:lat].to_f, params[:lng].to_f)

    render json: provider_profiles.map { |provider_profile|
      {
        id: provider_profile.id,
        name: provider_profile.user.name,
        category: provider_profile.category,
        latitude: provider_profile.latitude,
        longitude: provider_profile.longitude,
        logo_url: provider_profile.logo.attached? ? url_for(provider_profile.logo) : nil,
        url: provider_path(provider_profile)
      }
    }
  end
end
