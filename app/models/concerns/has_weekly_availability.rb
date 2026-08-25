module HasWeeklyAvailability
  extend ActiveSupport::Concern

  # Replaces every schedule row in one go on every save — simpler and
  # always-correct for a fixed 7-day form than accepts_nested_attributes_for
  # (whose reject_if only suppresses blank *new* rows, leaving a previously
  # persisted day unclearable without extra per-row destroy checkboxes).
  def replace_availability_windows!(windows_by_day)
    transaction do
      availabilities.destroy_all
      windows_by_day.each do |day_of_week, window|
        start_time = window[:start_time].presence
        end_time = window[:end_time].presence
        next unless start_time && end_time

        availabilities.create!(day_of_week: day_of_week, start_time: start_time, end_time: end_time)
      end
    end
  end
end
