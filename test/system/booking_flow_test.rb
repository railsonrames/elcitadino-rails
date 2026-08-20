require "application_system_test_case"

class BookingFlowTest < ApplicationSystemTestCase
  setup do
    @provider_profile = provider_profiles(:one)
    @service = services(:one)
  end

  test "client signs in, finds a provider, and books an appointment" do
    visit new_user_session_path
    fill_in "E-mail", with: users(:client_one).email
    fill_in "Senha", with: "password123"
    click_on "Login"

    assert_current_path providers_path

    click_on @provider_profile.user.name
    assert_selector "h1", text: @provider_profile.user.name

    click_on "Reservar"
    assert_selector "h1", text: "Reservar com #{@provider_profile.user.name}"

    click_button "09:00"
    fill_in "Observações", with: "Primeira visita."
    click_on "Confirmar agendamento"

    assert_text "Agendamento criado com sucesso."
    assert_selector "h1", text: "Detalhes do Agendamento"
  end

  test "provider confirms a pending appointment" do
    appointment = appointments(:one)

    visit new_user_session_path
    fill_in "E-mail", with: appointment.provider_profile.user.email
    fill_in "Senha", with: "password123"
    click_on "Login"

    visit appointment_path(appointment)
    click_on "Confirmar"

    assert_text "Agendamento atualizado com sucesso."
    assert appointment.reload.confirmed?
  end
end
