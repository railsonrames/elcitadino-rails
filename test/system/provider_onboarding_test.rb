require "application_system_test_case"

class ProviderOnboardingTest < ApplicationSystemTestCase
  test "provider signs up, completes profile, and adds a service" do
    visit new_user_registration_path

    fill_in "Nome Completo", with: "Ana Testadora"
    fill_in "E-mail", with: "ana.testadora@example.com"
    choose "Prestador"
    fill_in "Senha", with: "password123"
    fill_in "Confirme sua senha", with: "password123"
    click_on "Inscrever-se"

    assert_current_path new_provider_profile_path
    assert_selector "h1", text: "Complete seu perfil de prestador"

    fill_in "Sobre você", with: "Bio de teste."
    fill_in "Endereço", with: "Rua Teste, 1"
    fill_in "Cidade", with: "Alicante"
    select "Beleza & Estética", from: "Categoria"
    click_on "Salvar perfil"

    assert_current_path dashboard_path
    assert_selector "h1", text: "Painel do Prestador"

    click_on "Editar meu perfil e serviços"
    assert_current_path edit_provider_profile_path

    click_on "Novo serviço"
    fill_in "Nome do Serviço", with: "Corte Simples"
    fill_in "Duração (minutos)", with: 30
    fill_in "Preço", with: 20
    click_on "Salvar serviço"

    assert_current_path edit_provider_profile_path
    assert_text "Corte Simples"
  end
end
