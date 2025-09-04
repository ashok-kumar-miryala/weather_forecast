require "net/http"
require "json"
require "uri"

# Geocoding Client Adapter
# Default implementation uses Nominatim (OpenStreetMap) public API.
#
# For production, ensure you respect Nominatim usage policy and set a custom User-Agent.
# You may replace this with any provider by implementing #geocode(address) to return:
# {
#   lat: Float,
#   lon: Float,
#   postal_code: String|nil,
#   provider: "ProviderName"
# }

module Geocoding
  class Client
    NOMINATIM_ENDPOINT = "https://nominatim.openstreetmap.org/search".freeze
    USER_AGENT = ENV.fetch("GEOCODING_USER_AGENT", "WeatherForecastApp/1.0 (contact: admin@example.com)")

    def geocode(address)
      uri = URI(NOMINATIM_ENDPOINT)
      params = {
        q: address,
        format: "json",
        addressdetails: 1,
        limit: 1
      }
      uri.query = URI.encode_www_form(params)

      response = http_get(uri)
      data = JSON.parse(response.body)
      first = data.first
      return nil unless first

      {
        lat: first["lat"],
        lon: first["lon"],
        postal_code: first.dig("address", "postcode"),
        provider: "Nominatim"
      }
    rescue JSON::ParserError, Errno::ECONNREFUSED, Timeout::Error, SocketError, StandardError => e
      Rails.logger.warn("[Geocoding::Client] geocode error: #{e.class} - #{e.message}")
      nil
    end

    private

    def http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = 5
      http.open_timeout = 3

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      http.request(req)
    end
  end
end
