require "net/http"

class GeocodeProviderProfileJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3

  def perform(provider_profile_id)
    provider_profile = ProviderProfile.find_by(id: provider_profile_id)
    return unless provider_profile

    result = geocode(provider_profile)
    return unless result

    provider_profile.update_columns(latitude: result["lat"], longitude: result["lon"])
  end

  private

  def geocode(provider_profile)
    uri = URI("https://nominatim.openstreetmap.org/search")
    uri.query = URI.encode_www_form(
      q: "#{provider_profile.address}, #{provider_profile.city}, Spain", format: "json", limit: 1
    )

    request = Net::HTTP::Get.new(uri)
    # Nominatim's usage policy requires a descriptive User-Agent identifying the app.
    request["User-Agent"] = "ElCitadino/1.0 (contact: railson@msn.com)"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    JSON.parse(response.body).first
  end
end
