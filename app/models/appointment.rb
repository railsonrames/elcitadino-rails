class Appointment < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :provider_profile
  belongs_to :service

  enum :status, { pending: 0, confirmed: 1, completed: 2, canceled: 3 }, default: :pending
  enum :modality, { in_person: 0, online: 1, phone: 2, video: 3 }, default: :in_person

  validates :scheduled_at, presence: true
  validate :scheduled_at_cannot_be_in_the_past
  validate :client_must_be_client
  validate :no_overlapping_appointments, if: -> { scheduled_at.present? && provider_profile.present? }
  validate :scheduled_at_within_provider_availability, if: -> { scheduled_at.present? && provider_profile.present? && service.present? }

  scope :active, -> { where.not(status: :canceled) }
  scope :for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }

  def end_time
    scheduled_at + service.duration.minutes
  end

  private

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "não pode ser no passado")
    end
  end

  def client_must_be_client
    errors.add(:client, "deve ter o perfil de cliente") unless client&.client?
  end

  def scheduled_at_within_provider_availability
    if provider_profile.closed_on?(scheduled_at.to_date)
      errors.add(:scheduled_at, "o prestador não está disponível nesta data")
      return
    end

    windows = provider_profile.time_windows_for(scheduled_at.to_date, modality)
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
