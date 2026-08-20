class ProviderProfile < ApplicationRecord
  SLOT_INTERVAL = 30.minutes

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
  has_many :services, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :availabilities, class_name: "ProviderAvailability", dependent: :destroy
  has_many :time_offs, class_name: "ProviderTimeOff", dependent: :destroy

  validates :bio, :address, :city, presence: true
  validates :category, inclusion: { in: ProviderCategory::SLUGS }

  def closed_on?(date)
    time_offs.any? { |time_off| time_off.starts_on <= date && time_off.ends_on >= date }
  end

  # Returns [[[start_h,start_m],[end_h,end_m]], ...] for the given date,
  # filtered by modality when given (rules with no modality apply to all).
  def time_windows_for(date, modality = nil)
    return [] if closed_on?(date)

    rules = availabilities.select { |rule| rule.day_of_week == date.wday }
    rules = rules.select { |rule| rule.modality.nil? || rule.modality == modality } if modality.present?

    return rules.map { |rule| [ [ rule.start_time.hour, rule.start_time.min ], [ rule.end_time.hour, rule.end_time.min ] ] } if availabilities.any?

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

    windows = time_windows_for(date, modality)
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
end
