class ExpireUnconfirmedPaidAppointmentsJob < ApplicationJob
  queue_as :default

  def perform
    Appointment.awaiting_payment_confirmation_expired.find_each(&:expire_for_payment_confirmation_timeout!)
  end
end
