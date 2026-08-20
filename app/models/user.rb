class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :appointments, foreign_key: "client_id"
  has_one :provider_profile, dependent: :destroy

  enum :role, { client: 0, provider: 1 }
end
