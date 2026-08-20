class AppointmentsController < ApplicationController
  include DateParams

  ALLOWED_STATUS_TRANSITIONS = {
    "client" => %w[canceled],
    "provider" => %w[confirmed canceled completed]
  }.freeze

  MAX_BOOKING_DAYS_AHEAD = 60

  before_action :set_provider_profile, only: [ :new, :create ]
  before_action :require_client_role, only: [ :new, :create ]
  before_action :set_appointment, only: [ :show, :update, :reschedule ]
  before_action :require_provider_role, only: [ :reschedule ]

  def index
    @appointments = visible_appointments.order(scheduled_at: :desc)
  end

  def show
  end

  def new
    service = @provider_profile.services.find(params[:service_id])
    modality = requested_modality(params[:modality])
    build_attrs = { service_id: service.id }
    build_attrs[:modality] = modality if modality.present?
    @appointment = @provider_profile.appointments.build(build_attrs)
    load_booking_context(service, parse_date(params[:date]), modality)
  end

  def create
    service = @provider_profile.services.find(appointment_params[:service_id])
    @appointment = @provider_profile.appointments.build(appointment_params)
    @appointment.client = current_user

    if @appointment.save
      redirect_to @appointment, notice: t(".success")
    else
      load_booking_context(service, @appointment.scheduled_at&.to_date, @appointment.modality)
      render :new, status: :unprocessable_content
    end
  end

  def reschedule
    @provider_profile = @appointment.provider_profile
    load_booking_context(@appointment.service, parse_date(params[:date]) || @appointment.scheduled_at.to_date, @appointment.modality, exclude: @appointment)
  end

  def update
    if status_param.present?
      update_status
    elsif schedule_param.present?
      update_schedule
    else
      redirect_to @appointment, alert: t(".invalid_transition")
    end
  end

  private

  def set_provider_profile
    @provider_profile = ProviderProfile.find(params[:provider_id])
  end

  def require_client_role
    redirect_to root_path, alert: t("errors.clients_only") unless current_user.client?
  end

  def require_provider_role
    redirect_to root_path, alert: t("errors.providers_only") unless current_user.provider?
  end

  def update_status
    if allowed_status?(status_param) && @appointment.update(status: status_param)
      redirect_to @appointment, notice: t(".success")
    else
      redirect_to @appointment, alert: t(".invalid_transition")
    end
  end

  def update_schedule
    if current_user.provider? && @appointment.update(scheduled_at: schedule_param)
      redirect_to @appointment, notice: t(".rescheduled")
    else
      redirect_to @appointment, alert: t(".invalid_transition")
    end
  end

  def load_booking_context(service, date, modality, exclude: nil)
    @service = service
    @modality = requested_modality(modality)
    @selected_date = clamp_date(date || Date.tomorrow)
    @calendar_month = @selected_date.beginning_of_month
    @day_schedule = @provider_profile.day_schedule(date: @selected_date, service: service, modality: @modality, exclude: exclude)
  end

  def requested_modality(modality)
    return nil unless @provider_profile.modality_dependent?
    modality.presence_in(@provider_profile.configured_modalities) || @provider_profile.configured_modalities.first
  end

  def clamp_date(date)
    date.clamp(Date.current, Date.current + MAX_BOOKING_DAYS_AHEAD)
  end

  def visible_appointments
    if current_user.client?
      current_user.appointments
    else
      current_user.provider_profile&.appointments || Appointment.none
    end
  end

  def set_appointment
    @appointment = visible_appointments.find(params[:id])
  end

  def appointment_params
    params.expect(appointment: [ :service_id, :scheduled_at, :modality, :notes ])
  end

  def schedule_param
    params.dig(:appointment, :scheduled_at)
  end

  def status_param
    params.dig(:appointment, :status)
  end

  def allowed_status?(status)
    ALLOWED_STATUS_TRANSITIONS.fetch(current_user.role, []).include?(status)
  end
end
