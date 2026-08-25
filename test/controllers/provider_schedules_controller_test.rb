require "test_helper"

class ProviderSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider_profile = provider_profiles(:one)
  end

  test "requires authentication" do
    get edit_provider_profile_schedule_url
    assert_redirected_to new_user_session_url
  end

  test "provider sees the weekly hours editor" do
    sign_in users(:provider_one)
    get edit_provider_profile_schedule_url
    assert_response :success
  end

  test "provider can set their general weekly hours" do
    sign_in users(:provider_one)

    patch provider_profile_schedule_url, params: {
      provider_profile: { availability_windows: { "1" => { start_time: "09:00", end_time: "18:00" } } }
    }

    assert_redirected_to edit_provider_profile_schedule_url
    windows = @provider_profile.availabilities.reload
    assert_equal 1, windows.count
    assert_equal 1, windows.first.day_of_week
  end

  test "a user with no provider profile is redirected to onboarding" do
    sign_in users(:client_one)
    get edit_provider_profile_schedule_url
    assert_redirected_to new_provider_profile_url
  end
end
