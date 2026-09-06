require "test_helper"

class ProviderProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider_profile = provider_profiles(:one)
  end

  test "requires authentication" do
    get new_provider_profile_url
    assert_redirected_to new_user_session_url
  end

  test "provider can upload a logo when creating their profile" do
    user = User.create!(name: "Novo Prestador", email: "novo.prestador@example.com", password: "password123", role: :provider)
    sign_in user
    logo = fixture_file_upload("logo.png", "image/png")

    post provider_profile_url, params: {
      provider_profile: { bio: "Bio", address: "Rua Nova, 1", city: "Alicante", category: "beleza", logo: logo }
    }

    assert user.provider_profile.reload.logo.attached?
  end

  test "provider can upload a logo when updating their profile" do
    sign_in users(:provider_one)
    logo = fixture_file_upload("logo.png", "image/png")

    patch provider_profile_url, params: { provider_profile: { logo: logo } }

    assert @provider_profile.logo.attached?
  end

  test "provider can customize their slug" do
    sign_in users(:provider_one)

    patch provider_profile_url, params: { provider_profile: { slug: "meu-novo-link" } }

    assert_equal "meu-novo-link", @provider_profile.reload.slug
  end

  test "a duplicate slug fails validation and re-renders edit" do
    sign_in users(:provider_one)
    taken = provider_profiles(:two).slug

    patch provider_profile_url, params: { provider_profile: { slug: taken } }

    assert_response :unprocessable_content
    assert_not_equal taken, @provider_profile.reload.slug
  end
end
