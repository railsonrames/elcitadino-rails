require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @service = services(:one)
    @provider_profile = provider_profiles(:one)
  end

  test "requires authentication" do
    get new_provider_profile_service_url
    assert_redirected_to new_user_session_url
  end

  test "provider can create a service on their own profile" do
    sign_in users(:provider_one)

    assert_difference("@provider_profile.services.count") do
      post provider_profile_services_url, params: {
        service: { name: "Barba", description: "Aparar barba", duration: 20, price: 10 }
      }
    end

    assert_equal @provider_profile, Service.last.provider_profile
    assert_redirected_to edit_provider_profile_url
  end

  test "create ignores a client-supplied provider_profile_id" do
    sign_in users(:provider_one)
    other_profile = provider_profiles(:two)

    post provider_profile_services_url, params: {
      service: { name: "Barba", duration: 20, price: 10, provider_profile_id: other_profile.id }
    }

    assert_equal @provider_profile, Service.last.provider_profile
  end

  test "provider cannot edit another provider's service" do
    sign_in users(:provider_two)
    get edit_provider_profile_service_url(@service)
    assert_response :not_found
  end

  test "provider can update their own service" do
    sign_in users(:provider_one)
    patch provider_profile_service_url(@service), params: { service: { name: "Novo Nome" } }
    assert_redirected_to edit_provider_profile_url
    assert_equal "Novo Nome", @service.reload.name
  end

  test "provider can destroy their own service" do
    sign_in users(:provider_one)
    assert_difference("Service.count", -1) do
      delete provider_profile_service_url(services(:unbooked))
    end
  end

  test "provider cannot destroy a service with existing appointments" do
    sign_in users(:provider_one)
    assert_no_difference("Service.count") do
      delete provider_profile_service_url(@service)
    end
    assert_redirected_to edit_provider_profile_url
  end
end
