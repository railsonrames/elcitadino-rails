class ProviderSchedulesController < ApplicationController
  before_action :set_provider_profile

  def edit
  end

  def update
    @provider_profile.replace_availability_windows!(availability_windows_param)
    redirect_to edit_provider_profile_schedule_path, notice: t(".success")
  end

  private

  def set_provider_profile
    @provider_profile = current_user.provider_profile
    redirect_to new_provider_profile_path, alert: t("errors.no_provider_profile") unless @provider_profile
  end

  def availability_windows_param
    return {} unless params[:provider_profile][:availability_windows]

    params[:provider_profile][:availability_windows].to_unsafe_h.transform_keys(&:to_i).transform_values do |window|
      { start_time: window[:start_time], end_time: window[:end_time] }
    end
  end
end
