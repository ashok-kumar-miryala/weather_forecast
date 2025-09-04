require "net/http"
require "json"
require "uri"

# Weather Client Adapter
# Default implementation uses the Open-Meteo API (no API key required).
#
# Returns a hash:
# {
#   current_temp_c: Float,
#   daily_high_c: Float,
#   daily_low_c: Float,
#   provider: "Open-Meteo"
# }

module Weather
  class Client
    OPEN_METEO_ENDPOINT = "https://api.open-meteo.com/v1/forecast".freeze

    def fetch_current_and_daily(lat:, lon:)
      uri = URI(OPEN_METEO_ENDPOINT)
      params = {
        latitude: lat,
        longitude: lon,
        current: "temperature_2m",
        daily: "temperature_2m_max,temperature_2m_min",
        timezone: "auto"
      }
      uri.query = URI.encode_www_form(params)

      response = http_get(uri)
      data = JSON.parse(response.body)

      current_temp_c = data.dig("current", "temperature_2m")
      daily_high_c = data.dig("daily", "temperature_2m_max")&.first
      daily_low_c  = data.dig("daily", "temperature_2m_min")&.first

      {
        current_temp_c: current_temp_c,
        daily_high_c: daily_high_c,
        daily_low_c: daily_low_c,
        provider: "Open-Meteo"
      }
    rescue JSON::ParserError, Errno::ECONNREFUSED, Timeout::Error, SocketError, StandardError => e
      Rails.logger.warn("[Weather::Client] fetch_current_and_daily error: #{e.class} - #{e.message}")
      {
        current_temp_c: nil,
        daily_high_c: nil,
        daily_low_c: nil,
        provider: "Open-Meteo"
      }
    end

    private

    def http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = 5
      http.open_timeout = 3

      req = Net::HTTP::Get.new(uri)
      http.request(req)
    end
  end
end
