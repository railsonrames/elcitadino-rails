class ProviderTimeOff < ApplicationRecord
  belongs_to :provider_profile

  validates :starts_on, :ends_on, presence: true
  validate :ends_on_not_before_starts_on

  scope :covering, ->(date) { where("starts_on <= ? AND ends_on >= ?", date, date) }

  private

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "deve ser depois ou igual à data de início") if ends_on < starts_on
  end
end
