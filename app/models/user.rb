class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :appointments, foreign_key: "client_id"
  has_one :provider_profile, dependent: :destroy
  has_one :notification_preference, dependent: :destroy

  enum :role, { client: 0, provider: 1 }

  # A user with no NotificationPreference row yet (hasn't visited the
  # settings page) behaves like one with every channel at its default
  # (all true) — the row is only created on first save.
  def notify_whatsapp?
    notification_preference.nil? || notification_preference.notify_whatsapp?
  end

  def notify_push?
    notification_preference.nil? || notification_preference.notify_push?
  end

  def notify_email?
    notification_preference.nil? || notification_preference.notify_email?
  end
end
