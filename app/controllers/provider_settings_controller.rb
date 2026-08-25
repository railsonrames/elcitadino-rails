class ProviderSettingsController < ApplicationController
  before_action :set_provider_profile

  def edit
  end

  def update
    if @provider_profile.update(setting_params)
      redirect_to edit_provider_profile_setting_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_provider_profile
    @provider_profile = current_user.provider_profile
    redirect_to new_provider_profile_path, alert: t("errors.no_provider_profile") unless @provider_profile
  end

  def setting_params
    params.expect(provider_profile: [ :allow_client_reschedule, :listed ])
  end
end
