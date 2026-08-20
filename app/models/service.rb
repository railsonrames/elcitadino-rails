class Service < ApplicationRecord
  belongs_to :provider_profile
  has_many :appointments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
