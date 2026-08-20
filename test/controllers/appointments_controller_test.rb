require "test_helper"

class AppointmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @appointment = appointments(:one)
    @provider_profile = provider_profiles(:one)
    @service = services(:one)
  end

  test "requires authentication" do
    get appointments_url
    assert_redirected_to new_user_session_url
  end

  test "client sees only their own appointments" do
    sign_in users(:client_one)
    get appointments_url
    assert_response :success
    assert_match @appointment.notes, response.body
  end

  test "provider cannot access another provider's appointment" do
    sign_in users(:provider_two)
    get appointment_url(@appointment)
    assert_response :not_found
  end

  test "client can book a new appointment with a provider" do
    sign_in users(:client_one)

    assert_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "in_person", notes: "Test" }
      }
    end

    appointment = Appointment.last
    assert_equal users(:client_one), appointment.client
    assert_equal @provider_profile, appointment.provider_profile
    assert appointment.pending?
    assert_redirected_to appointment_url(appointment)
  end

  test "booking as a provider is rejected" do
    sign_in users(:provider_one)

    assert_no_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "in_person" }
      }
    end
  end

  test "create ignores a client-supplied client_id/provider_profile_id/status" do
    sign_in users(:client_one)
    other_client = users(:client_two)

    post provider_appointments_url(@provider_profile), params: {
      appointment: {
        service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "in_person",
        client_id: other_client.id, provider_profile_id: provider_profiles(:two).id, status: "confirmed"
      }
    }

    appointment = Appointment.last
    assert_equal users(:client_one), appointment.client
    assert_equal @provider_profile, appointment.provider_profile
    assert appointment.pending?
  end

  test "provider can confirm a pending appointment" do
    sign_in users(:provider_one)
    patch appointment_url(@appointment), params: { appointment: { status: "confirmed" } }
    assert_redirected_to appointment_url(@appointment)
    assert @appointment.reload.confirmed?
  end

  test "client cannot confirm their own appointment" do
    sign_in users(:client_one)
    patch appointment_url(@appointment), params: { appointment: { status: "confirmed" } }
    assert_not @appointment.reload.confirmed?
  end

  test "client can cancel their own appointment" do
    sign_in users(:client_one)
    patch appointment_url(@appointment), params: { appointment: { status: "canceled" } }
    assert @appointment.reload.canceled?
  end

  test "reschedule is provider-only" do
    sign_in users(:client_one)
    get reschedule_appointment_url(@appointment)
    assert_redirected_to root_url
  end

  test "reschedule renders the calendar for the owning provider" do
    sign_in users(:provider_one)
    get reschedule_appointment_url(@appointment)
    assert_response :success
  end

  test "provider can reschedule an appointment to a new open slot" do
    sign_in users(:provider_one)
    new_time = 4.days.from_now.change(hour: 12, min: 0, sec: 0)

    patch appointment_url(@appointment), params: { appointment: { scheduled_at: new_time } }

    assert_redirected_to appointment_url(@appointment)
    assert_equal new_time.to_i, @appointment.reload.scheduled_at.to_i
  end

  test "client cannot reschedule an appointment" do
    sign_in users(:client_one)
    original_time = @appointment.scheduled_at
    new_time = 4.days.from_now.change(hour: 12, min: 0, sec: 0)

    patch appointment_url(@appointment), params: { appointment: { scheduled_at: new_time } }

    assert_equal original_time.to_i, @appointment.reload.scheduled_at.to_i
  end

  test "rescheduling to a time outside the provider's availability is rejected" do
    sign_in users(:provider_one)
    original_time = @appointment.scheduled_at
    out_of_hours = 4.days.from_now.change(hour: 23, min: 0, sec: 0)

    patch appointment_url(@appointment), params: { appointment: { scheduled_at: out_of_hours } }

    assert_equal original_time.to_i, @appointment.reload.scheduled_at.to_i
  end
end
