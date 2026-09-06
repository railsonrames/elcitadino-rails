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
        service: { name: "Barba", description: "Aparar barba", duration: 20, price: 10, modalities: [ "in_person" ] }
      }
    end

    assert_equal @provider_profile, Service.last.provider_profile
    assert_redirected_to edit_provider_profile_url
  end

  test "create ignores a client-supplied provider_profile_id" do
    sign_in users(:provider_one)
    other_profile = provider_profiles(:two)

    post provider_profile_services_url, params: {
      service: { name: "Barba", duration: 20, price: 10, modalities: [ "in_person" ], provider_profile_id: other_profile.id }
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

  test "provider can set a service-specific weekly schedule when creating a service" do
    sign_in users(:provider_one)

    assert_difference("ProviderAvailability.count", 1) do
      post provider_profile_services_url, params: {
        service: {
          name: "Aluguel de trasteiro", duration: 60, price: 20, modalities: [ "in_person" ],
          availability_windows: { "1" => { start_time: "10:00", end_time: "11:00" } }
        }
      }
    end

    windows = Service.last.availabilities
    assert_equal 1, windows.count
    assert_equal 1, windows.first.day_of_week
  end

  test "provider can replace a service's schedule on update, including clearing it entirely" do
    sign_in users(:provider_one)
    @service.availabilities.create!(day_of_week: 1, start_time: "10:00", end_time: "11:00")

    patch provider_profile_service_url(@service), params: { service: { name: @service.name, availability_windows: {} } }

    assert_empty @service.availabilities.reload
  end

  test "provider can set which modalities a service is offered through" do
    sign_in users(:provider_one)

    post provider_profile_services_url, params: {
      service: { name: "Consulta Online", duration: 30, price: 25, modalities: [ "online", "phone" ] }
    }

    assert_equal %w[online phone], Service.last.modalities
  end

  test "creating a service without any modality is rejected" do
    sign_in users(:provider_one)

    assert_no_difference("Service.count") do
      post provider_profile_services_url, params: { service: { name: "Sem modalidade", duration: 20, price: 10 } }
    end
  end

  test "provider can set the video call link and phone number for their service" do
    sign_in users(:provider_one)

    post provider_profile_services_url, params: {
      service: {
        name: "Consulta Flex", duration: 30, price: 25, modalities: [ "online", "phone" ],
        video_call_link: "https://meet.example.com/room-1", phone_number: "+34 900 000 000"
      }
    }

    service = Service.last
    assert_equal "https://meet.example.com/room-1", service.video_call_link
    assert_equal "+34 900 000 000", service.phone_number
  end

  test "provider can upload a photo when creating a service" do
    sign_in users(:provider_one)
    photo = fixture_file_upload("logo.png", "image/png")

    post provider_profile_services_url, params: { service: { name: "Barba", duration: 20, price: 10, modalities: [ "in_person" ], photo: photo } }

    assert Service.last.photo.attached?
  end

  test "provider can require payment confirmation with a deposit, instructions, and a custom deadline" do
    sign_in users(:provider_one)

    patch provider_profile_service_url(@service), params: {
      service: {
        requires_payment_confirmation: true, deposit_amount: 15, payment_instructions: "Pay via Bizum to 600000000",
        payment_confirmation_window_minutes: 60
      }
    }

    @service.reload
    assert @service.requires_payment_confirmation?
    assert_equal 15, @service.deposit_amount.to_i
    assert_equal "Pay via Bizum to 600000000", @service.payment_instructions
    assert_equal 60, @service.payment_confirmation_window_minutes
  end
end
