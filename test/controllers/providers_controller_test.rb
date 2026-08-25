require "test_helper"

class ProvidersControllerTest < ActionDispatch::IntegrationTest
  test "index excludes unlisted providers" do
    unlisted = provider_profiles(:one)
    unlisted.update!(listed: false)

    get providers_url

    assert_not_includes response.body, unlisted.user.name
  end

  test "show still renders an unlisted provider's page directly" do
    unlisted = provider_profiles(:one)
    unlisted.update!(listed: false)

    get provider_url(unlisted)

    assert_response :success
  end

  test "nearby excludes unlisted providers even when in range" do
    unlisted = provider_profiles(:one)
    unlisted.update!(listed: false, latitude: 38.35, longitude: -0.48)

    get nearby_providers_url(lat: 38.3452, lng: -0.4810), as: :json

    ids = JSON.parse(response.body).map { |provider| provider["id"] }
    assert_not_includes ids, unlisted.id
  end

  test "nearby does not require authentication" do
    get nearby_providers_url(lat: 38.3452, lng: -0.4810), as: :json
    assert_response :success
  end

  test "nearby returns providers within range, closest first, excluding ones with no coordinates" do
    near = provider_profiles(:one)
    near.update_columns(latitude: 38.35, longitude: -0.48)
    far = provider_profiles(:two)
    far.update_columns(latitude: 41.38, longitude: 2.17) # Barcelona — outside the default radius
    ProviderProfile.where.not(id: [ near.id, far.id ]).update_all(latitude: nil, longitude: nil)

    get nearby_providers_url(lat: 38.3452, lng: -0.4810), as: :json

    ids = JSON.parse(response.body).map { |provider| provider["id"] }
    assert_includes ids, near.id
    assert_not_includes ids, far.id
  end

  test "nearby includes a logo_url only when the provider has one attached" do
    provider = provider_profiles(:one)
    provider.update_columns(latitude: 38.35, longitude: -0.48)

    get nearby_providers_url(lat: 38.3452, lng: -0.4810), as: :json

    entry = JSON.parse(response.body).find { |p| p["id"] == provider.id }
    assert_nil entry["logo_url"]
  end
end
