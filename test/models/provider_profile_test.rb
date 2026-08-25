require "test_helper"

class ProviderProfileTest < ActiveSupport::TestCase
  setup do
    @provider_profile = provider_profiles(:one)
    @service = services(:one)
  end

  test "available_slots is empty for a past date" do
    assert_empty @provider_profile.available_slots(date: Date.yesterday, service: @service)
  end

  test "allow_client_reschedule? defaults to true" do
    assert @provider_profile.allow_client_reschedule?
  end

  test "allow_client_reschedule? reflects the persisted value once changed" do
    @provider_profile.update!(allow_client_reschedule: false)

    assert_not @provider_profile.allow_client_reschedule?
  end

  test "available_slots excludes any slot overlapping an existing appointment" do
    appointment = appointments(:one)
    date = appointment.scheduled_at.to_date
    busy_range = appointment.scheduled_at...appointment.end_time

    slots = @provider_profile.available_slots(date: date, service: @service)

    slots.each do |slot|
      slot_range = slot...(slot + @service.duration.minutes)
      overlaps = slot_range.begin < busy_range.end && busy_range.begin < slot_range.end
      assert_not overlaps, "expected #{slot} to not overlap busy window #{busy_range}"
    end
  end

  test "available_slots only includes future times for today" do
    travel_to Time.zone.local(2030, 1, 15, 14, 0) do
      slots = @provider_profile.available_slots(date: Date.current, service: @service)
      times = slots.map { |slot| slot.strftime("%H:%M") }

      assert slots.all? { |slot| slot > Time.current }
      assert_includes times, "14:30"
      assert_not_includes times, "14:00"
    end
  end

  test "available_slots falls back to 9-19 every day when the provider has no availability rules" do
    date = Date.tomorrow
    closing = date.in_time_zone.change(hour: 19, min: 0)
    last_valid_start = closing - @service.duration.minutes

    slots = @provider_profile.available_slots(date: date, service: @service)

    assert_includes slots, last_valid_start
    assert_not_includes slots, closing
  end

  test "available_slots respects a provider's own weekly hours once configured" do
    monday = Date.tomorrow.next_occurring(:monday)
    saturday = monday.next_occurring(:saturday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "08:00", end_time: "18:00")

    monday_slots = @provider_profile.available_slots(date: monday, service: @service)
    saturday_slots = @provider_profile.available_slots(date: saturday, service: @service)

    assert_includes monday_slots.map { |s| s.strftime("%H:%M") }, "08:00"
    assert_not_includes monday_slots.map { |s| s.strftime("%H:%M") }, "18:00"
    assert_empty saturday_slots, "Saturday has no configured rule once the provider has explicit hours"
  end

  test "available_slots is empty on a day covered by a time off" do
    date = Date.tomorrow
    @provider_profile.time_offs.create!(starts_on: date, ends_on: date + 3.days)

    assert_empty @provider_profile.available_slots(date: date, service: @service)
    assert @provider_profile.closed_on?(date)
  end

  test "available_slots filters by modality when the provider has modality-scoped rules" do
    tuesday = Date.tomorrow.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "09:00", end_time: "12:00", modality: "online")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "16:00", end_time: "21:00", modality: "in_person")

    online_slots = @provider_profile.available_slots(date: tuesday, service: @service, modality: "online").map { |s| s.strftime("%H:%M") }
    in_person_slots = @provider_profile.available_slots(date: tuesday, service: @service, modality: "in_person").map { |s| s.strftime("%H:%M") }

    assert_includes online_slots, "09:00"
    assert_not_includes online_slots, "16:00"
    assert_includes in_person_slots, "16:00"
    assert_not_includes in_person_slots, "09:00"
    assert @provider_profile.modality_dependent?
    assert_equal %w[online in_person], @provider_profile.configured_modalities
  end

  test "day_schedule marks out-of-hours slots as closed instead of omitting them" do
    monday = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "08:00", end_time: "18:00")

    schedule = @provider_profile.day_schedule(date: monday, service: @service)
    early_slot = schedule.find { |slot| slot[:time].strftime("%H:%M") == "07:00" }

    assert_equal :closed, early_slot[:status]
  end

  test "day_schedule with exclude: does not treat the excluded appointment's own slot as booked" do
    appointment = appointments(:one)
    date = appointment.scheduled_at.to_date

    without_exclude = @provider_profile.day_schedule(date: date, service: @service)
    with_exclude = @provider_profile.day_schedule(date: date, service: @service, exclude: appointment)

    own_slot_without = without_exclude.find { |slot| slot[:time] == appointment.scheduled_at }
    own_slot_with = with_exclude.find { |slot| slot[:time] == appointment.scheduled_at }

    assert_equal :booked, own_slot_without[:status]
    assert_equal :available, own_slot_with[:status]
  end

  test "next_available_slot finds the first open slot on or after the given date" do
    monday = Date.tomorrow.next_occurring(:monday)
    tuesday = monday.next_occurring(:tuesday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "08:00", end_time: "08:30")
    @provider_profile.availabilities.create!(day_of_week: tuesday.wday, start_time: "08:00", end_time: "18:00")

    @provider_profile.appointments.create!(
      client: users(:client_one), service: @service, modality: "in_person", scheduled_at: monday.in_time_zone.change(hour: 8)
    )

    slot = @provider_profile.next_available_slot(after: monday, service: @service)

    assert_equal tuesday, slot.to_date
    assert_equal "08:00", slot.strftime("%H:%M")
  end

  test "next_available_slot returns nil when nothing opens up within the search window" do
    monday = Date.tomorrow.next_occurring(:monday)
    @provider_profile.time_offs.create!(starts_on: monday, ends_on: monday + 90.days)

    assert_nil @provider_profile.next_available_slot(after: monday, service: @service, search_days: 10)
  end

  test "available_slots ignores the provider's general hours once a service has its own rules" do
    monday = Date.tomorrow.next_occurring(:monday)
    wednesday = monday.next_occurring(:wednesday)
    @service.availabilities.create!(day_of_week: monday.wday, start_time: "09:00", end_time: "10:00")

    monday_slots = @provider_profile.available_slots(date: monday, service: @service)
    wednesday_slots = @provider_profile.available_slots(date: wednesday, service: @service)

    assert_includes monday_slots.map { |s| s.strftime("%H:%M") }, "09:00"
    assert_empty wednesday_slots, "a day the service has no rule for should be closed, not fall back to the provider's hours"
  end

  test "next_available_slot_near picks the exact original time on the first day it's free" do
    monday = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "09:00", end_time: "18:00")

    slot = @provider_profile.next_available_slot_near(after: monday, original_time: monday.in_time_zone.change(hour: 14), service: @service)

    assert_equal "14:00", slot.strftime("%H:%M")
    assert_equal monday, slot.to_date
  end

  test "next_available_slot_near picks the closest slot within two positions when the exact time is booked" do
    monday = Date.tomorrow.next_occurring(:monday)
    @provider_profile.availabilities.create!(day_of_week: monday.wday, start_time: "09:00", end_time: "18:00")
    @provider_profile.appointments.create!(
      client: users(:client_one), service: @service, modality: "in_person", scheduled_at: monday.in_time_zone.change(hour: 14)
    )

    slot = @provider_profile.next_available_slot_near(after: monday, original_time: monday.in_time_zone.change(hour: 14), service: @service)

    assert_equal monday, slot.to_date
    assert_includes [ "13:30", "14:30" ], slot.strftime("%H:%M")
  end

  test "next_available_slot_near falls back to the nearest date once the proximity window is exhausted" do
    monday = Date.tomorrow.next_occurring(:monday)
    far_day = monday + 10.days
    @provider_profile.time_offs.create!(starts_on: monday, ends_on: far_day - 1.day)
    @provider_profile.availabilities.create!(day_of_week: far_day.wday, start_time: "09:00", end_time: "10:00")

    slot = @provider_profile.next_available_slot_near(after: monday, original_time: monday.in_time_zone.change(hour: 14), service: @service)

    assert_equal far_day, slot.to_date
    assert_equal "09:00", slot.strftime("%H:%M")
  end

  test "near returns providers within radius ordered by distance, excluding ones with no coordinates" do
    close = provider_profiles(:one)
    close.update_columns(latitude: 38.35, longitude: -0.48) # ~1km from the search point
    far = provider_profiles(:two)
    far.update_columns(latitude: 41.38, longitude: 2.17) # Barcelona — well outside the default radius
    ProviderProfile.where.not(id: [ close.id, far.id ]).update_all(latitude: nil, longitude: nil)

    results = ProviderProfile.near(38.3452, -0.4810)

    assert_equal [ close ], results
  end

  test "creating a profile with an address enqueues a geocoding job" do
    user = User.create!(name: "Novo", email: "novo.geocode@example.com", password: "password123", role: :provider)

    assert_enqueued_with(job: GeocodeProviderProfileJob) do
      ProviderProfile.create!(user: user, bio: "Bio", address: "Rua Teste, 1", city: "Alicante", category: "beleza")
    end
  end

  test "setting latitude/longitude directly does not enqueue a geocoding job" do
    user = User.create!(name: "Novo", email: "novo.geocode2@example.com", password: "password123", role: :provider)

    assert_no_enqueued_jobs(only: GeocodeProviderProfileJob) do
      ProviderProfile.create!(
        user: user, bio: "Bio", address: "Rua Teste, 1", city: "Alicante", category: "beleza",
        latitude: 38.35, longitude: -0.48
      )
    end
  end

  test "updating an unrelated attribute does not enqueue a geocoding job" do
    assert_no_enqueued_jobs(only: GeocodeProviderProfileJob) do
      @provider_profile.update!(bio: "Nova bio")
    end
  end
end
