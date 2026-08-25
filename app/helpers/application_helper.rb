module ApplicationHelper
  LOCALE_NAMES = { "pt-BR" => "Português", "es" => "Español", "en" => "English", "va" => "Valencià" }.freeze

  def locale_name(locale)
    LOCALE_NAMES.fetch(locale.to_s, locale.to_s)
  end

  # A provider account can also be the client on someone else's booking, so
  # the viewer's perspective on a given appointment comes from their
  # relationship to it, never from their account's own role.
  def appointment_provider_view?(appointment)
    appointment.provider_profile.user_id == current_user.id
  end
end
