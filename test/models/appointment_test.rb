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
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "12:00", modality: "video")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "16:00", end_time: "21:00", modality: "in_person")

    appointment = build_appointment(scheduled_at: tuesday.in_time_zone.change(hour: 10), modality: "in_person")

    assert_not appointment.valid?
  end

  test "valid when the modality matches its configured window" do
    tuesday = Date.tomorrow.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "12:00", modality: "video")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "16:00", end_time: "21:00", modality: "in_person")

    appointment = build_appointment(scheduled_at: tuesday.in_time_zone.change(hour: 17), modality: "in_person")

    assert appointment.valid?
  end
end
