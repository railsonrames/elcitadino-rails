module AppointmentsHelper
  def calendar_weeks(month)
    grid_start = month.beginning_of_month.beginning_of_week(:sunday)
    grid_end = month.end_of_month.end_of_week(:sunday)
    (grid_start..grid_end).map { |date| [ date, date.month == month.month ] }.each_slice(7).to_a
  end
end
