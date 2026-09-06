require "test_helper"

class ExpireUnconfirmedPaidAppointmentsJobTest < ActiveSupport::TestCase
  setup do
    @provider_profile = provider_profiles(:one)
    @service = services(:one)
    @client = users(:client_one)
    @service.update!(requires_payment_confirmation: true, deposit_amount: 10, payment_instructions: "Pay via Bizum")
  end

  def build_appointment(scheduled_at:)
    Appointment.new(client: @client, provider_profile: @provider_profile, service: @service, scheduled_at: scheduled_at, modality: "in_person")
  end

  test "cancels a pending appointment whose payment confirmation deadline has passed" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10))
    appointment.save!
    appointment.update_column(:payment_confirmation_deadline_at, 1.hour.ago)

    ExpireUnconfirmedPaidAppointmentsJob.perform_now

    assert appointment.reload.canceled?
  end

  test "leaves a confirmed appointment untouched even if its deadline has passed" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 12))
    appointment.save!
    appointment.update_columns(status: :confirmed, payment_confirmation_deadline_at: 1.hour.ago)

    ExpireUnconfirmedPaidAppointmentsJob.perform_now

    assert appointment.reload.confirmed?
  end

  test "leaves a pending appointment whose deadline hasn't passed yet untouched" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 14))
    appointment.save!

    ExpireUnconfirmedPaidAppointmentsJob.perform_now

    assert appointment.reload.pending?
  end
end
