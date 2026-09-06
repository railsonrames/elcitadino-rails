class ProviderProfilesController < ApplicationController
  before_action :require_provider_role
  before_action :redirect_if_profile_exists, only: [ :new, :create ]
  before_action :set_provider_profile, only: [ :edit, :update ]

  def new
    @provider_profile = current_user.build_provider_profile
  end

  def create
    @provider_profile = current_user.build_provider_profile(provider_profile_params)

    if @provider_profile.save
      redirect_to dashboard_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @provider_profile.update(provider_profile_params)
      redirect_to edit_provider_profile_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def require_provider_role
    redirect_to root_path, alert: t("errors.providers_only") unless current_user.provider?
  end

  def redirect_if_profile_exists
    redirect_to edit_provider_profile_path if current_user.provider_profile.present?
  end

  def set_provider_profile
    @provider_profile = current_user.provider_profile || raise(ActiveRecord::RecordNotFound)
  end

  def provider_profile_params
    params.expect(provider_profile: [ :bio, :address, :city, :category, :logo, :slug ])
  end
end
