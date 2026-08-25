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

  # Renders a QR code entirely server-side (rqrcode, no external service or
  # JS library) as a data URI, so it can be dropped straight into an
  # image_tag — using <img> rather than an inline <svg> is deliberate: it's
  # what lets the browser's native "save image"/<a download> both work.
  def qr_code_data_uri(url)
    svg = RQRCode::QRCode.new(url).as_svg(module_size: 6, standalone: true, use_path: true)
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
