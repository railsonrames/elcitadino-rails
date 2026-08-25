require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:client_one)
  end

  test "profile hub shows read-only name and email, no editable fields" do
    sign_in @user
    get edit_user_registration_url
    assert_response :success
    assert_select "input[type=text]", false
    assert_select "input[type=email]", false
  end

  test "changing password with the correct current password succeeds" do
    sign_in @user
    put user_registration_url, params: {
      user: { password: "newpassword123", password_confirmation: "newpassword123", current_password: "password123" }
    }
    assert_redirected_to edit_user_registration_url
  end

  test "changing password with the wrong current password re-renders the password page with the error" do
    sign_in @user
    put user_registration_url, params: {
      user: { password: "newpassword123", password_confirmation: "newpassword123", current_password: "wrongpassword" }
    }
    assert_response :unprocessable_content
    assert_select "#error_explanation"
  end
end
