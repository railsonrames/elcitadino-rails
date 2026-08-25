require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  setup do
    @provider_profile = provider_profiles(:one)
    @service = services(:one)
    @client = users(:client_one)
  end

  def build_appointment(scheduled_at:, modality: "in_person")
    Appointment.new(
      client: @client,
      provider_profile: @provider_profile,
      service: @service,
      scheduled_at: scheduled_at,
      modality: modality
    )
  end

  test "valid within the provider's default 9-19 fallback window" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10))

    assert appointment.valid?
  end

  test "invalid outside the provider's configured hours" do
    monday = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "08:00", end_time: "18:00")

    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 19))

    assert_not appointment.valid?
    assert_includes appointment.errors[:scheduled_at], "está fora do horário de atendimento do prestador"
  end

  test "invalid on a day covered by a time off" do
    date = Date.tomorrow
    @provider_profile.time_offs.create!(starts_on: date, ends_on: date + 2.days)

    appointment = build_appointment(scheduled_at: date.in_time_zone.change(hour: 10))

    assert_not appointment.valid?
    assert_includes appointment.errors[:scheduled_at], "o prestador não está disponível nesta data"
  end

  test "invalid when the modality isn't offered at that time" do
    tuesday = Date.tomorrow.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "12:00", modality: "online")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "16:00", end_time: "21:00", modality: "in_person")

    appointment = build_appointment(scheduled_at: tuesday.in_time_zone.change(hour: 10), modality: "in_person")

    assert_not appointment.valid?
  end

  test "valid when the modality matches its configured window" do
    tuesday = Date.tomorrow.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "12:00", modality: "online")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "16:00", end_time: "21:00", modality: "in_person")

    appointment = build_appointment(scheduled_at: tuesday.in_time_zone.change(hour: 17), modality: "in_person")

    assert appointment.valid?
  end

  test "invalid when the client is the provider profile's own user" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = Appointment.new(
      client: users(:provider_one), provider_profile: @provider_profile, service: @service,
      scheduled_at: monday.in_time_zone.change(hour: 10), modality: "in_person"
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:client], "não pode agendar consigo mesmo"
  end

  test "a service's own schedule fully replaces the provider's general hours, not adds to them" do
    monday = Date.tomorrow.next_occurring(:monday)
    tuesday = monday.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "18:00")
    @service.availabilities.create!(day_of_week: monday.wday, start_time: "09:00", end_time: "10:00")

    on_service_day = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 9))
    on_provider_only_day = build_appointment(scheduled_at: tuesday.in_time_zone.change(hour: 10))

    assert on_service_day.valid?
    assert_not on_provider_only_day.valid?, "a service with its own rules should not fall back to the provider's general hours"
  end

  test "invalid when the modality isn't one the service offers" do
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10), modality: "online")

    assert_not appointment.valid?
    assert_not_empty appointment.errors[:modality]
  end

  test "valid when the modality is one the service offers" do
    @service.update!(modalities: [ "in_person", "online" ])
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10), modality: "online")

    assert appointment.valid?
  end

  test "valid without a phone number when the modality is phone (the client's own number is optional)" do
    @service.update!(modalities: [ "phone" ])
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10), modality: "phone")

    assert appointment.valid?
    assert_nil appointment.phone_number
  end

  test "valid with the client's own phone number set" do
    @service.update!(modalities: [ "phone" ])
    monday = Date.tomorrow.next_occurring(:monday)
    appointment = build_appointment(scheduled_at: monday.in_time_zone.change(hour: 10), modality: "phone")
    appointment.phone_number = "+34 600 000 000"

    assert appointment.valid?
  end
end
