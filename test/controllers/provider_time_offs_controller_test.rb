require "test_helper"

class ProviderTimeOffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider_profile = provider_profiles(:one)
  end

  test "requires authentication" do
    post provider_profile_time_offs_url(date: Date.tomorrow.iso8601)
    assert_redirected_to new_user_session_url
  end

  test "provider can block a date with no appointments" do
    sign_in users(:provider_one)
    date = Date.tomorrow

    assert_difference("ProviderTimeOff.count") do
      post provider_profile_time_offs_url(date: date.iso8601)
    end

    time_off = @provider_profile.time_offs.last
    assert_equal date, time_off.starts_on
    assert_equal date, time_off.ends_on
  end

  test "blocking a date reschedules its appointments to their next open slot" do
    sign_in users(:provider_one)
    date = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: date.wday, start_time: "09:00", end_time: "18:00")
    @provider_profile.availabilities.create!(day_of_week: date.next_occurring(:tuesday).wday, start_time: "09:00", end_time: "18:00")

    appointment = @provider_profile.appointments.create!(
      client: users(:client_one), service: services(:one), modality: "in_person",
      scheduled_at: date.in_time_zone.change(hour: 10)
    )

    post provider_profile_time_offs_url(date: date.iso8601)

    assert_redirected_to dashboard_url(date: date)
    appointment.reload
    assert_not_equal date, appointment.scheduled_at.to_date
    assert appointment.valid?
    assert @provider_profile.time_offs.reload.any? { |t| t.starts_on == date }
  end

  test "blocking a date rolls back entirely if an appointment can't be rescheduled" do
    sign_in users(:provider_one)
    date = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: date.wday, start_time: "09:00", end_time: "18:00")
    @provider_profile.time_offs.create!(starts_on: date + 1, ends_on: date + 90)

    appointment = @provider_profile.appointments.create!(
      client: users(:client_one), service: services(:one), modality: "in_person",
      scheduled_at: date.in_time_zone.change(hour: 10)
    )

    assert_no_difference("ProviderTimeOff.count") do
      post provider_profile_time_offs_url(date: date.iso8601)
    end

    assert_equal date, appointment.reload.scheduled_at.to_date
  end

  test "provider can unblock a date" do
    sign_in users(:provider_one)
    time_off = @provider_profile.time_offs.create!(starts_on: Date.tomorrow, ends_on: Date.tomorrow)

    assert_difference("ProviderTimeOff.count", -1) do
      delete provider_profile_time_off_url(time_off)
    end
  end

  test "provider can block a date range, rescheduling every appointment across it into one time_off row" do
    sign_in users(:provider_one)
    monday = Date.tomorrow.next_occurring(:monday)
    wednesday = monday.next_occurring(:wednesday)
    friday = monday.next_occurring(:friday)
    saturday = monday.next_occurring(:saturday)
    [ monday, wednesday, friday, saturday ].each do |date|
      @provider_profile.availabilities.create!(day_of_week: date.wday, start_time: "09:00", end_time: "18:00")
    end

    appointment_one = @provider_profile.appointments.create!(
      client: users(:client_one), service: services(:one), modality: "in_person", scheduled_at: monday.in_time_zone.change(hour: 10)
    )
    appointment_two = @provider_profile.appointments.create!(
      client: users(:client_one), service: services(:one), modality: "in_person", scheduled_at: wednesday.in_time_zone.change(hour: 11)
    )

    assert_difference("ProviderTimeOff.count", 1) do
      post provider_profile_time_offs_url(start_date: monday.iso8601, end_date: friday.iso8601)
    end

    assert_equal 1, @provider_profile.time_offs.reload.count { |t| t.starts_on == monday && t.ends_on == friday }
    assert appointment_one.reload.scheduled_at.to_date > friday
    assert appointment_two.reload.scheduled_at.to_date > friday
  end

  test "blocking a date range rolls back entirely if any appointment in it can't be rescheduled" do
    sign_in users(:provider_one)
    monday = Date.tomorrow.next_occurring(:monday)
    tuesday = monday.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "09:00", end_time: "18:00")
    @provider_profile.time_offs.create!(starts_on: tuesday + 1, ends_on: tuesday + 90)

    appointment = @provider_profile.appointments.create!(
      client: users(:client_one), service: services(:one), modality: "in_person", scheduled_at: monday.in_time_zone.change(hour: 10)
    )

    assert_no_difference("ProviderTimeOff.count") do
      post provider_profile_time_offs_url(start_date: monday.iso8601, end_date: tuesday.iso8601)
    end

    assert_equal monday, appointment.reload.scheduled_at.to_date
  end
end
