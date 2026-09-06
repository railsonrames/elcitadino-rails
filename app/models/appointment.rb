class Appointment < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :provider_profile
  belongs_to :service

  enum :status, { pending: 0, confirmed: 1, completed: 2, canceled: 3 }, default: :pending
  # "video" was retired as a separate value — it's the same as "online",
  # just with a video-call link attached (see video_call_link below).
  enum :modality, { in_person: 0, online: 1, phone: 2 }, default: :in_person

  validates :scheduled_at, presence: true
  validates :modality, inclusion: { in: ->(appointment) { appointment.service.modalities } }, if: -> { service.present? }
  validate :scheduled_at_cannot_be_in_the_past
  validate :client_cannot_book_own_provider_profile
  validate :no_overlapping_appointments, if: -> { scheduled_at.present? && provider_profile.present? }
  validate :scheduled_at_within_provider_availability, if: -> { scheduled_at.present? && provider_profile.present? && service.present? }

  scope :active, -> { where.not(status: :canceled) }
  scope :for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }
  scope :awaiting_payment_confirmation_expired, -> {
    pending.where.not(payment_confirmation_deadline_at: nil).where("payment_confirmation_deadline_at < ?", Time.current)
  }

  before_create :set_payment_confirmation_deadline

  def end_time
    scheduled_at + service.duration.minutes
  end

  def expire_for_payment_confirmation_timeout!
    update!(status: :canceled)
    # Notification hook: when the notification system is built, this is
    # where the client should be told their booking fell through because
    # the provider didn't confirm in time (see NotificationPreference).
  end

  private

  # Capped at scheduled_at: a booking made shortly before its own start
  # time (e.g. 1 hour out, on a service with a 2-hour window) must not get
  # a deadline after the appointment itself.
  def set_payment_confirmation_deadline
    return unless service&.requires_payment_confirmation?
    window_deadline = Time.current + service.payment_confirmation_window_minutes.minutes
    self.payment_confirmation_deadline_at = [ window_deadline, scheduled_at ].min
  end

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "não pode ser no passado")
    end
  end

  def client_cannot_book_own_provider_profile
    errors.add(:client, "não pode agendar consigo mesmo") if provider_profile&.user_id == client_id
  end

  def scheduled_at_within_provider_availability
    if provider_profile.closed_on?(scheduled_at.to_date)
      errors.add(:scheduled_at, "o prestador não está disponível nesta data")
      return
    end

    windows = provider_profile.time_windows_for(scheduled_at.to_date, modality, service: service)
    fits = windows.any? do |start_hm, end_hm|
      window_start = scheduled_at.in_time_zone.change(hour: start_hm[0], min: start_hm[1])
      window_end = scheduled_at.in_time_zone.change(hour: end_hm[0], min: end_hm[1])
      scheduled_at >= window_start && end_time <= window_end
    end

    errors.add(:scheduled_at, "está fora do horário de atendimento do prestador") unless fits
  end

  def no_overlapping_appointments
    overlapping = Appointment.active
      .where(provider_profile_id: provider_profile_id)
      .where.not(id: id)
      .joins(:service)
      .where("(appointments.scheduled_at, appointments.scheduled_at + services.duration * interval '1 minute') OVERLAPS (?,?)", scheduled_at, end_time)
    if overlapping.exists?
      errors.add(:scheduled_at, "o prestador já possui um agendamento que sobrepõe este horário")
    end
  end
end
