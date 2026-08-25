require "test_helper"

class NotificationPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get edit_notification_preference_url
    assert_redirected_to new_user_session_url
  end

  test "client sees preferences defaulting to enabled" do
    sign_in users(:client_one)
    get edit_notification_preference_url
    assert_response :success
  end

  test "provider sees preferences too (same channels as clients)" do
    sign_in users(:provider_one)
    get edit_notification_preference_url
    assert_response :success
  end

  test "user can update their preferences" do
    sign_in users(:client_one)

    assert_difference("NotificationPreference.count") do
      patch notification_preference_url, params: {
        notification_preference: { notify_whatsapp: "0", notify_push: "1", notify_email: "1" }
      }
    end

    assert_redirected_to edit_notification_preference_url
    preference = users(:client_one).notification_preference.reload
    assert_not preference.notify_whatsapp?
    assert preference.notify_push?
    assert preference.notify_email?
  end
end
