require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:client_one)
  end

  test "notification helpers default to true with no preference row yet" do
    assert_nil @user.notification_preference
    assert @user.notify_whatsapp?
    assert @user.notify_push?
    assert @user.notify_email?
  end

  test "notification helpers reflect the persisted row once one exists" do
    @user.build_notification_preference(notify_whatsapp: false).save!

    assert_not @user.notify_whatsapp?
    assert @user.notify_push?
    assert @user.notify_email?
  end
end
