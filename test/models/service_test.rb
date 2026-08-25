require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @service = services(:one)
  end

  test "invalid without at least one modality" do
    @service.modalities = []

    assert_not @service.valid?
    assert_not_empty @service.errors[:modalities]
  end

  test "valid with at least one modality" do
    @service.modalities = [ "online" ]

    assert @service.valid?
  end

  test "valid without a video call link" do
    @service.video_call_link = nil

    assert @service.valid?
  end

  test "rejects a video call link that isn't a plain http(s) URL" do
    @service.video_call_link = "javascript:alert(1)"

    assert_not @service.valid?
    assert_not_empty @service.errors[:video_call_link]
  end

  test "accepts a valid https video call link" do
    @service.video_call_link = "https://meet.example.com/room-123"

    assert @service.valid?
  end

  test "safe_video_call_link returns nil for anything that isn't http(s)" do
    @service.video_call_link = nil
    assert_nil @service.safe_video_call_link
  end

  test "safe_video_call_link returns the link when it's a valid http(s) URL" do
    @service.video_call_link = "https://meet.example.com/room-123"
    assert_equal "https://meet.example.com/room-123", @service.safe_video_call_link
  end
end
