class ProviderAvailability < ApplicationRecord
  belongs_to :provider_profile
  belongs_to :service, optional: true

  enum :modality, Appointment.modalities

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validate :end_after_start

  # Rows created through `service.availabilities.create!` only get
  # service_id set by that association — provider_profile_id (still
  # required, every rule belongs to a provider either way) is derived from
  # the service instead of needing to be passed explicitly every time.
  before_validation :set_provider_profile_from_service, if: -> { provider_profile_id.blank? && service.present? }

  private

  def set_provider_profile_from_service
    self.provider_profile_id = service.provider_profile_id
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "deve ser depois do horário de início") if end_time <= start_time
  end
end
