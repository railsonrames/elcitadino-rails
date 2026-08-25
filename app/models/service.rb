class Service < ApplicationRecord
  include HasWeeklyAvailability

  belongs_to :provider_profile
  has_one_attached :photo
  has_many :appointments, dependent: :restrict_with_error
  has_many :availabilities, class_name: "ProviderAvailability", dependent: :destroy

  validates :name, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :modalities, presence: true
  # Rendered as a clickable link, so only http(s) is accepted — otherwise a
  # provider could store a javascript: URI as their "video call link".
  validates :video_call_link, format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true

  # The format validation above already guarantees any *stored* value is a
  # plain http(s) URL, but this re-checks at read time too (defense in
  # depth) and gives the view a value it can link to directly without
  # inlining the check itself.
  def safe_video_call_link
    video_call_link if video_call_link&.match?(%r{\Ahttps?://\S+\z}i)
  end
end
