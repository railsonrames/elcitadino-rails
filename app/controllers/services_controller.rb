class ServicesController < ApplicationController
  before_action :set_provider_profile
  before_action :set_service, only: [ :edit, :update, :destroy ]

  def new
    @service = @provider_profile.services.build
  end

  def create
    @service = @provider_profile.services.build(service_params)

    if @service.save
      @service.replace_availability_windows!(availability_windows_param)
      redirect_to edit_provider_profile_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      @service.replace_availability_windows!(availability_windows_param)
      redirect_to edit_provider_profile_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @service.destroy
      redirect_to edit_provider_profile_path, notice: t(".success")
    else
      redirect_to edit_provider_profile_path, alert: @service.errors.full_messages.to_sentence
    end
  end

  private

  def set_provider_profile
    @provider_profile = current_user.provider_profile
    redirect_to new_provider_profile_path, alert: t("errors.no_provider_profile") unless @provider_profile
  end

  def set_service
    @service = @provider_profile.services.find(params[:id])
  end

  def service_params
    params.expect(service: [ :name, :description, :duration, :price, :photo, :video_call_link, :phone_number,
      :requires_payment_confirmation, :deposit_amount, :payment_instructions, :payment_confirmation_window_minutes,
      modalities: [] ])
  end

  # A flat { "0" => { start_time:, end_time: }, ..., "6" => {...} } hash,
  # one entry per weekday — kept separate from service_params since it
  # doesn't map onto a Service column, it drives replace_availability_windows!.
  def availability_windows_param
    return {} unless params[:service][:availability_windows]

    params[:service][:availability_windows].to_unsafe_h.transform_keys(&:to_i).transform_values do |window|
      { start_time: window[:start_time], end_time: window[:end_time] }
    end
  end
end
