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
    assert_match @appointment.service.name, response.body
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

  test "a provider can book an appointment with a different provider" do
    sign_in users(:provider_two)

    assert_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "in_person" }
      }
    end

    assert_equal users(:provider_two), Appointment.last.client
  end

  test "a provider cannot book an appointment with themselves" do
    sign_in users(:provider_one)

    assert_no_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "in_person" }
      }
    end
  end

  test "a provider cannot confirm their own appointment booked as a client (viewpoint must not follow account role)" do
    appointment = @provider_profile.appointments.create!(
      client: users(:provider_two), service: @service, modality: "in_person",
      scheduled_at: 3.days.from_now.next_occurring(:monday).change(hour: 10, min: 0, sec: 0)
    )

    sign_in users(:provider_two)
    patch appointment_url(appointment), params: { appointment: { status: "confirmed" } }

    assert_not appointment.reload.confirmed?
  end

  test "booking with a modality the service doesn't offer is rejected" do
    sign_in users(:client_one)

    assert_no_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "online" }
      }
    end
  end

  test "booking by phone without a phone number succeeds (the client's own number is optional)" do
    sign_in users(:client_one)
    @service.update!(modalities: [ "phone" ])

    assert_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "phone" }
      }
    end
  end

  test "booking by phone with a phone number succeeds" do
    sign_in users(:client_one)
    @service.update!(modalities: [ "phone" ])

    post provider_appointments_url(@provider_profile), params: {
      appointment: {
        service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
        modality: "phone", phone_number: "+34 600 000 000"
      }
    }

    assert_equal "+34 600 000 000", Appointment.last.phone_number
  end

  test "booking online without a video call link succeeds" do
    sign_in users(:client_one)
    @service.update!(modalities: [ "online" ])

    assert_difference("Appointment.count") do
      post provider_appointments_url(@provider_profile), params: {
        appointment: { service_id: @service.id, scheduled_at: 2.days.from_now.change(hour: 10, min: 0, sec: 0), modality: "online" }
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

  test "client can reschedule when the provider allows it (default)" do
    sign_in users(:client_one)
    assert @provider_profile.allow_client_reschedule?, "provider setting should default to allowed"

    get reschedule_appointment_url(@appointment)
    assert_response :success

    new_time = 4.days.from_now.change(hour: 12, min: 0, sec: 0)
    patch appointment_url(@appointment), params: { appointment: { scheduled_at: new_time } }

    assert_redirected_to appointment_url(@appointment)
    assert_equal new_time.to_i, @appointment.reload.scheduled_at.to_i
  end

  test "client cannot reschedule when the provider has disabled it" do
    @provider_profile.update!(allow_client_reschedule: false)
    sign_in users(:client_one)
    original_time = @appointment.scheduled_at

    get reschedule_appointment_url(@appointment)
    assert_redirected_to appointment_url(@appointment)

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
