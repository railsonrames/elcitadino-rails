class AppointmentsController < ApplicationController
  include DateParams

  ALLOWED_STATUS_TRANSITIONS = {
    client: %w[canceled],
    provider: %w[confirmed canceled completed]
  }.freeze

  MAX_BOOKING_DAYS_AHEAD = 60

  before_action :set_provider_profile, only: [ :new, :create ]
  before_action :set_appointment, only: [ :show, :update, :reschedule ]
  before_action :require_reschedule_permission, only: [ :reschedule ]

  def index
    @scope = params[:scope] == "past" ? "past" : "upcoming"
    @own_appointments = scoped_appointments(current_user.appointments)
    @client_appointments = current_user.provider_profile ? scoped_appointments(current_user.provider_profile.appointments) : Appointment.none
  end

  def show
  end

  def new
    service = @provider_profile.services.find(params[:service_id])
    modality = requested_modality(service, params[:modality])
    @appointment = @provider_profile.appointments.build(service_id: service.id, modality: modality)
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

  # Upcoming shows soonest-first (what you'd act on next); past shows most-recent-first
  # (what you'd look back at). @scope is set in #index.
  def scoped_appointments(relation)
    if @scope == "past"
      relation.where(scheduled_at: ...Time.current).order(scheduled_at: :desc)
    else
      relation.where(scheduled_at: Time.current..).order(scheduled_at: :asc)
    end
  end

  def set_provider_profile
    @provider_profile = ProviderProfile.find(params[:provider_id])
  end

  def require_reschedule_permission
    redirect_to @appointment, alert: t("errors.reschedule_not_allowed") unless can_reschedule?(@appointment)
  end

  # Viewpoint on a given appointment comes from the relationship to that
  # appointment, never the account's own role — a provider account can also
  # be the client on someone else's booking, and must be treated as a
  # client there, not as a provider.
  def viewpoint(appointment)
    return :provider if appointment.provider_profile.user_id == current_user.id
    :client if appointment.client_id == current_user.id
  end

  def can_reschedule?(appointment)
    return true if viewpoint(appointment) == :provider
    viewpoint(appointment) == :client && appointment.status.in?(%w[pending confirmed]) && appointment.provider_profile.allow_client_reschedule?
  end

  def update_status
    if allowed_status?(status_param) && @appointment.update(status: status_param)
      redirect_to @appointment, notice: t(".success")
    else
      redirect_to @appointment, alert: t(".invalid_transition")
    end
  end

  def update_schedule
    if can_reschedule?(@appointment) && @appointment.update(scheduled_at: schedule_param)
      redirect_to @appointment, notice: t(".rescheduled")
    else
      redirect_to @appointment, alert: t(".invalid_transition")
    end
  end

  def load_booking_context(service, date, modality, exclude: nil)
    @service = service
    @modality = requested_modality(service, modality)
    @selected_date = clamp_date(date || Date.tomorrow)
    @calendar_month = @selected_date.beginning_of_month
    @day_schedule = @provider_profile.day_schedule(date: @selected_date, service: service, modality: @modality, exclude: exclude)
  end

  # A service always offers at least one modality (validated), so this
  # always resolves to a real value — never nil — which matters downstream:
  # day_schedule/time_windows_for only filters ProviderAvailability rules by
  # modality when one is given, so an unresolved nil would wrongly include
  # rules scoped to modalities this service doesn't even offer.
  def requested_modality(service, modality)
    modality.presence_in(service.modalities) || service.modalities.first
  end

  def clamp_date(date)
    date.clamp(Date.current, Date.current + MAX_BOOKING_DAYS_AHEAD)
  end

  def set_appointment
    scope = Appointment.where(client: current_user)
    scope = scope.or(Appointment.where(provider_profile: current_user.provider_profile)) if current_user.provider_profile
    @appointment = scope.find(params[:id])
  end

  def appointment_params
    params.expect(appointment: [ :service_id, :scheduled_at, :modality, :notes, :phone_number ])
  end

  def schedule_param
    params.dig(:appointment, :scheduled_at)
  end

  def status_param
    params.dig(:appointment, :status)
  end

  def allowed_status?(status)
    ALLOWED_STATUS_TRANSITIONS.fetch(viewpoint(@appointment), []).include?(status)
  end
end
