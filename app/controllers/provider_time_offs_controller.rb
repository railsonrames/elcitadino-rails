class ProviderTimeOffsController < ApplicationController
  include DateParams

  class UnreschedulableError < StandardError
    attr_reader :appointment

    def initialize(appointment)
      @appointment = appointment
      super("no available slot for #{appointment.service.name}")
    end
  end

  before_action :set_provider_profile

  def create
    date = parse_date(params[:date])
    return redirect_to dashboard_path, alert: t(".invalid_date") unless date && date >= Date.current

    affected = @provider_profile.appointments.active.for_date(date)

    if affected.any?
      reschedule_and_block!(date, affected)
    else
      @provider_profile.time_offs.create!(starts_on: date, ends_on: date)
    end

    redirect_to dashboard_path(date: date), notice: t(".success")
  rescue UnreschedulableError => e
    redirect_to dashboard_path(date: date), alert: t(".reschedule_failed", service: e.appointment.service.name)
  end

  def destroy
    time_off = @provider_profile.time_offs.find(params[:id])
    starts_on = time_off.starts_on
    time_off.destroy!
    redirect_to dashboard_path(date: starts_on), notice: t(".unblocked")
  end

  private

  def set_provider_profile
    @provider_profile = current_user.provider_profile
    redirect_to new_provider_profile_path, alert: t("errors.no_provider_profile") unless @provider_profile
  end

  def reschedule_and_block!(date, appointments)
    ActiveRecord::Base.transaction do
      appointments.each do |appointment|
        next_slot = @provider_profile.next_available_slot(after: date + 1, service: appointment.service, modality: appointment.modality)
        raise UnreschedulableError, appointment unless next_slot
        appointment.update!(scheduled_at: next_slot)
      end
      @provider_profile.time_offs.create!(starts_on: date, ends_on: date)
    end
  end
end
