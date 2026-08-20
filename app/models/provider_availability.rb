class ProviderAvailability < ApplicationRecord
  belongs_to :provider_profile

  enum :modality, Appointment.modalities

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validate :end_after_start

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "deve ser depois do horário de início") if end_time <= start_time
  end
end
