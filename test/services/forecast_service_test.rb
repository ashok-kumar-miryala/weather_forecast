require "test_helper"

class ForecastServiceTest < ActiveSupport::TestCase
  class MockGeocodingClient
    def initialize(lat:, lon:, postal_code: nil)
      @lat = lat
      @lon = lon
      @postal_code = postal_code
    end

    def geocode(_address)
      { lat: @lat, lon: @lon, postal_code: @postal_code, provider: "MockGeo" }
    end
  end

  class MockWeatherClient
    def initialize(temp_c:, high_c:, low_c:)
      @temp_c = temp_c
      @high_c = high_c
      @low_c = low_c
    end

    def fetch_current_and_daily(lat:, lon:)
      raise "coords missing" if lat.nil? || lon.nil?

      {
        current_temp_c: @temp_c,
        daily_high_c: @high_c,
        daily_low_c: @low_c,
        provider: "MockWeather"
      }
    end
  end

  setup do
    Rails.cache.clear
  end

  test "fetch caches by ZIP from input address" do
    svc = ForecastService.new(
      geocoding_client: MockGeocodingClient.new(lat: 1.0, lon: 2.0),
      weather_client: MockWeatherClient.new(temp_c: 10.0, high_c: 15.0, low_c: 5.0)
    )

    address = "1 Test St, City, State 12345-6789"
    result1 = svc.fetch(address)
    assert_equal "12345", result1.zip
    assert_equal false, result1.from_cache

    # Second call should hit cache
    result2 = svc.fetch(address)
    assert_equal "12345", result2.zip
    assert_equal true, result2.from_cache
    assert_equal result1.current_temp_c, result2.current_temp_c
  end

  test "fetch uses geocoded postal_code when not present in input" do
    svc = ForecastService.new(
      geocoding_client: MockGeocodingClient.new(lat: 1.0, lon: 2.0, postal_code: "20500"),
      weather_client: MockWeatherClient.new(temp_c: 20.0, high_c: 25.0, low_c: 15.0)
    )

    address_without_zip = "1600 Pennsylvania Ave NW, Washington, DC"
    result = svc.fetch(address_without_zip)
    assert_equal "20500", result.zip

    # Now subsequent request with any address that results in same zip should be cached
    result2 = svc.fetch("White House, DC")
    assert_equal true, result2.from_cache
  end

  test "does not cache when no ZIP available" do
    svc = ForecastService.new(
      geocoding_client: MockGeocodingClient.new(lat: 1.0, lon: 2.0, postal_code: nil),
      weather_client: MockWeatherClient.new(temp_c: 10.0, high_c: 15.0, low_c: 5.0)
    )

    address = "Unknown place"
    result1 = svc.fetch(address)
    assert_nil result1.zip
    assert_equal false, result1.from_cache

    result2 = svc.fetch(address)
    assert_equal false, result2.from_cache
  end

  test "raises on blank address" do
    svc = ForecastService.new(
      geocoding_client: MockGeocodingClient.new(lat: 1.0, lon: 2.0),
      weather_client: MockWeatherClient.new(temp_c: 10.0, high_c: 15.0, low_c: 5.0)
    )
    assert_raises(ForecastService::UserInputError) { svc.fetch("") }
  end
end
