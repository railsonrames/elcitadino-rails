class ProviderProfile < ApplicationRecord
  belongs_to :user
  has_many :services, dependent: :destroy
  has_many :appointments, dependent: :destroy
end
