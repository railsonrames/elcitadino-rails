class ServicesController < ApplicationController
  before_action :set_provider_profile
  before_action :set_service, only: [ :edit, :update, :destroy ]

  def new
    @service = @provider_profile.services.build
  end

  def create
    @service = @provider_profile.services.build(service_params)

    if @service.save
      redirect_to edit_provider_profile_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
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
    params.expect(service: [ :name, :description, :duration, :price ])
  end
end
