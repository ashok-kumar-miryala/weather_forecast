require "test_helper"
require "ostruct"

class WeatherClientTest < ActiveSupport::TestCase
  test "fetch_current_and_daily parses typical open-meteo response" do
    client = Weather::Client.new
    fake_body = {
      "current" => { "temperature_2m" => 21.3 },
      "daily" => {
        "temperature_2m_max" => [26.5],
        "temperature_2m_min" => [15.2]
      }
    }.to_json

    client.stub(:http_get, OpenStruct.new(body: fake_body)) do
      res = client.fetch_current_and_daily(lat: 1.0, lon: 2.0)
      assert_equal 21.3, res[:current_temp_c]
      assert_equal 26.5, res[:daily_high_c]
      assert_equal 15.2, res[:daily_low_c]
    end
  end

  test "fetch_current_and_daily handles exception returning nil values" do
    client = Weather::Client.new
    client.stub(:http_get, ->(_uri) { raise Timeout::Error }) do
      res = client.fetch_current_and_daily(lat: 1.0, lon: 2.0)
      assert_nil res[:current_temp_c]
      assert_nil res[:daily_high_c]
      assert_nil res[:daily_low_c]
    end
  end
end
