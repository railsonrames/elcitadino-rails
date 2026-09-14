class DashboardController < ApplicationController
  include DateParams

  before_action :require_provider_profile

  def show
    @selected_date = parse_date(params[:date]) || Date.current
    @calendar_month = @selected_date.beginning_of_month

    @day_appointments = @provider_profile.appointments.active.for_date(@selected_date).includes(:client, :service).order(:scheduled_at)
    @blocking_time_off = @provider_profile.time_offs.find { |t| t.starts_on <= @selected_date && t.ends_on >= @selected_date }
    @appointment_dates = dates_with_appointments_in(@calendar_month)
    @blocked_dates = blocked_dates_in(@calendar_month)

    @monthly_revenue = @provider_profile.appointments.confirmed
      .where(scheduled_at: Date.current.beginning_of_month..Date.current.end_of_month)
      .joins(:service).sum("services.price")

    # "Citas hoy" no cabeçalho — sempre o dia de hoje, independente do dia selecionado
    # no calendário (@day_appointments acima é o dia selecionado, pode ser outro).
    @today_appointments_count = @provider_profile.appointments.active.for_date(Date.current).count
  end

  private

  def dates_with_appointments_in(month)
    range = month.in_time_zone.beginning_of_day..month.end_of_month.in_time_zone.end_of_day
    @provider_profile.appointments.active.where(scheduled_at: range).pluck(:scheduled_at).map(&:to_date).to_set
  end

  def blocked_dates_in(month)
    month_end = month.end_of_month
    @provider_profile.time_offs
      .select { |time_off| time_off.starts_on <= month_end && time_off.ends_on >= month }
      .flat_map { |time_off| ([ time_off.starts_on, month ].max..[ time_off.ends_on, month_end ].min).to_a }
      .to_set
  end

  def require_provider_profile
    return redirect_to root_path, alert: t("errors.providers_only") unless current_user.provider?

    @provider_profile = current_user.provider_profile
    redirect_to new_provider_profile_path, alert: t("errors.no_provider_profile") unless @provider_profile
  end
end
