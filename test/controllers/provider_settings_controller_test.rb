require "test_helper"

class ProviderSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider_profile = provider_profiles(:one)
  end

  test "requires authentication" do
    get edit_provider_profile_setting_url
    assert_redirected_to new_user_session_url
  end

  test "provider sees the toggle defaulting to enabled" do
    sign_in users(:provider_one)
    get edit_provider_profile_setting_url
    assert_response :success
  end

  test "provider can update the setting" do
    sign_in users(:provider_one)

    patch provider_profile_setting_url, params: { provider_profile: { allow_client_reschedule: "0" } }

    assert_redirected_to edit_provider_profile_setting_url
    assert_not @provider_profile.reload.allow_client_reschedule?
  end

  test "provider can make their profile unlisted" do
    sign_in users(:provider_one)

    patch provider_profile_setting_url, params: { provider_profile: { listed: "0" } }

    assert_redirected_to edit_provider_profile_setting_url
    assert_not @provider_profile.reload.listed?
  end

  test "a user with no provider profile is redirected to onboarding" do
    sign_in users(:client_one)
    get edit_provider_profile_setting_url
    assert_redirected_to new_provider_profile_url
  end
end
