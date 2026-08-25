require "test_helper"

class GeocodeProviderProfileJobTest < ActiveSupport::TestCase
  setup do
    @provider_profile = provider_profiles(:one)
  end

  test "sets latitude/longitude from a successful geocoding response" do
    stub_nominatim('[{"lat":"38.3452","lon":"-0.4810"}]') do
      GeocodeProviderProfileJob.perform_now(@provider_profile.id)
    end

    @provider_profile.reload
    assert_in_delta 38.3452, @provider_profile.latitude.to_f, 0.0001
    assert_in_delta(-0.4810, @provider_profile.longitude.to_f, 0.0001)
  end

  test "leaves coordinates nil when nothing is found" do
    stub_nominatim("[]") do
      GeocodeProviderProfileJob.perform_now(@provider_profile.id)
    end

    assert_nil @provider_profile.reload.latitude
  end

  test "does nothing when the provider profile no longer exists" do
    assert_nothing_raised do
      GeocodeProviderProfileJob.perform_now(-1)
    end
  end

  private

  # Minitest 6 dropped Object#stub/Minitest::Mock into a separate gem, so a
  # single external HTTP call is stubbed with plain Ruby instead of pulling
  # in a mocking library for this one job test.
  def stub_nominatim(body)
    canned_response = Struct.new(:body).new(body)
    original_start = Net::HTTP.method(:start)

    Net::HTTP.define_singleton_method(:start) { |*_args, **_kwargs, &_block| canned_response }
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end
end
