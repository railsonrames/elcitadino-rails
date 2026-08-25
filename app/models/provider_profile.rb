class ProviderProfile < ApplicationRecord
  include HasWeeklyAvailability

  SLOT_INTERVAL = 30.minutes

  # How next_available_slot_near prioritizes closeness to the original
  # time over closeness in date: within this many days, only a slot within
  # PROXIMITY_SLOTS of the original time counts; past it, any slot on the
  # nearest date is accepted instead.
  PROXIMITY_SEARCH_DAYS = 7
  PROXIMITY_SLOTS = 2

  # Fallback used only for providers with no ProviderAvailability rows at
  # all — matches the previous global behavior exactly (every day, 9-19,
  # no modality restriction), so providers nobody has configured yet (and
  # existing fixtures/tests) keep working unchanged.
  DEFAULT_WINDOW = [ [ 9, 0 ], [ 19, 0 ] ].freeze

  # Fixed bounds for the visual day grid shown to clients — a constant
  # shape across every provider, wide enough to cover every seeded
  # scenario (06:00-22:00), not a per-provider computed range.
  GRID_START = [ 6, 0 ].freeze
  GRID_END = [ 22, 0 ].freeze

  belongs_to :user
  has_one_attached :logo
  has_many :services, dependent: :destroy
  has_many :appointments, dependent: :destroy
  # Provider-wide rules only — a service with its own schedule (service_id
  # set) is reached through that service, not through this association, so
  # configured_modalities/time_windows_for's fallback never mixes the two.
  has_many :availabilities, -> { where(service_id: nil) }, class_name: "ProviderAvailability", dependent: :destroy
  has_many :time_offs, class_name: "ProviderTimeOff", dependent: :destroy

  validates :bio, :address, :city, presence: true
  validates :category, inclusion: { in: ProviderCategory::SLUGS }

  # Nominatim's usage policy caps requests at 1/sec and must never block a
  # save, so geocoding always happens out-of-band in a background job.
  # Skipped when latitude/longitude were set directly in the same save (e.g.
  # demo seed data using known city coordinates) — an explicit value should
  # never get silently overwritten by a lookup.
  after_commit :enqueue_geocoding, if: -> {
    (saved_change_to_address? || saved_change_to_city?) && !saved_change_to_latitude? && !saved_change_to_longitude?
  }

  # Plain Haversine distance in SQL — enough at this app's scale (a few
  # dozen to low hundreds of providers); PostGIS would be overkill here.
  # Postgres can't reference a SELECT alias from WHERE, so the radius is
  # applied in Ruby afterwards instead of repeating the formula — fine at
  # this row count.
  scope :near, ->(lat, lng, radius_km: 50) {
    where(listed: true)
      .where.not(latitude: nil, longitude: nil)
      .select("provider_profiles.*, (6371 * acos(
        cos(radians(#{lat})) * cos(radians(latitude)) * cos(radians(longitude) - radians(#{lng})) +
        sin(radians(#{lat})) * sin(radians(latitude))
      )) AS distance_km")
      .order("distance_km")
      .limit(30)
      .select { |provider_profile| provider_profile.distance_km <= radius_km }
  }

  # allow_client_reschedule? comes for free from the boolean column
  # (Rails' automatic attribute query method) — the column has a DB
  # default of true, backfilled onto every existing row at migration
  # time, so there's no nil-row case to guard against here.

  def closed_on?(date)
    time_offs.any? { |time_off| time_off.starts_on <= date && time_off.ends_on >= date }
  end

  # Returns [[[start_h,start_m],[end_h,end_m]], ...] for the given date,
  # filtered by modality when given (rules with no modality apply to all).
  # A service with any schedule rows of its own fully replaces the
  # provider-wide rules for it (not additive) — a weekday with no matching
  # service row is closed, it does not fall back to the provider's hours.
  def time_windows_for(date, modality = nil, service: nil)
    return [] if closed_on?(date)

    scoped = service&.availabilities&.any? ? service.availabilities : availabilities
    rules = scoped.select { |rule| rule.day_of_week == date.wday }
    rules = rules.select { |rule| rule.modality.nil? || rule.modality == modality } if modality.present?

    return rules.map { |rule| [ [ rule.start_time.hour, rule.start_time.min ], [ rule.end_time.hour, rule.end_time.min ] ] } if scoped.any?

    [ DEFAULT_WINDOW ]
  end

  def configured_modalities
    availabilities.filter_map(&:modality).uniq
  end

  def modality_dependent?
    configured_modalities.any?
  end

  def open_on?(date, modality = nil)
    date >= Time.zone.today && time_windows_for(date, modality).any?
  end

  def next_available_slot(after:, service:, modality: nil, search_days: 60, exclude: nil)
    (0..search_days).each do |offset|
      slot = available_slots(date: after + offset, service: service, modality: modality, exclude: exclude).first
      return slot if slot
    end
    nil
  end

  # Like next_available_slot, but tries to preserve the original time of
  # day: for the first PROXIMITY_SEARCH_DAYS days it only accepts a slot
  # within PROXIMITY_SLOTS of original_time (closest one wins), picking the
  # closest matching day first; past that window it gives up on time
  # proximity and just takes the earliest slot on the nearest date.
  def next_available_slot_near(after:, original_time:, service:, modality: nil, exclude: nil, search_days: 60)
    proximity_days = [ search_days, PROXIMITY_SEARCH_DAYS ].min

    (0..proximity_days).each do |offset|
      slots = available_slots(date: after + offset, service: service, modality: modality, exclude: exclude)
      closest = closest_slot_within_proximity(slots, original_time)
      return closest if closest
    end

    next_available_slot(
      after: after + proximity_days + 1, service: service, modality: modality,
      search_days: search_days - proximity_days - 1, exclude: exclude
    )
  end

  def available_slots(date:, service:, modality: nil, exclude: nil)
    day_schedule(date: date, service: service, modality: modality, exclude: exclude)
      .select { |slot| slot[:status] == :available }
      .map { |slot| slot[:time] }
  end

  # Full 06:00-22:00 grid classified per slot, so the UI can render
  # disabled buttons for out-of-hours/booked times instead of omitting them.
  # `exclude:` leaves one appointment's own current booking out of the busy
  # windows — used when rescheduling it, so its old slot doesn't block
  # nearby times on the same day it's about to vacate.
  def day_schedule(date:, service:, modality: nil, exclude: nil)
    return [] if date < Time.zone.today

    windows = time_windows_for(date, modality, service: service)
    busy_windows = appointments.active.for_date(date).includes(:service)
      .reject { |appointment| appointment == exclude }
      .map { |appointment| appointment.scheduled_at...appointment.end_time }

    grid_start = date.in_time_zone.change(hour: GRID_START[0], min: GRID_START[1])
    grid_end = date.in_time_zone.change(hour: GRID_END[0], min: GRID_END[1])

    schedule = []
    slot_start = grid_start
    while slot_start + service.duration.minutes <= grid_end
      slot_end = slot_start + service.duration.minutes
      schedule << { time: slot_start, status: slot_status(slot_start, slot_end, windows, busy_windows, date) }
      slot_start += SLOT_INTERVAL
    end
    schedule
  end

  private

  def slot_status(slot_start, slot_end, windows, busy_windows, date)
    return :past if slot_start <= Time.current
    return :booked if busy_windows.any? { |busy| slot_start < busy.end && busy.begin < slot_end }
    return :available if windows.any? { |start_hm, end_hm| within_window?(date, slot_start, slot_end, start_hm, end_hm) }
    :closed
  end

  def within_window?(date, slot_start, slot_end, start_hm, end_hm)
    window_start = date.in_time_zone.change(hour: start_hm[0], min: start_hm[1])
    window_end = date.in_time_zone.change(hour: end_hm[0], min: end_hm[1])
    slot_start >= window_start && slot_end <= window_end
  end

  def closest_slot_within_proximity(slots, original_time)
    original_minutes = original_time.hour * 60 + original_time.min
    max_delta = PROXIMITY_SLOTS * (SLOT_INTERVAL.to_i / 60)

    slots.select { |slot| (slot.hour * 60 + slot.min - original_minutes).abs <= max_delta }
      .min_by { |slot| (slot.hour * 60 + slot.min - original_minutes).abs }
  end

  def enqueue_geocoding
    GeocodeProviderProfileJob.perform_later(id)
  end
end
