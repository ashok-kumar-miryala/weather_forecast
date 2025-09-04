require "test_helper"
require "ostruct"

# Network-free test by stubbing http_get. Ensures JSON parsing and address extraction pipeline.
class GeocodingClientTest < ActiveSupport::TestCase
  test "geocode parses basic response" do
    client = Geocoding::Client.new
    fake_body = [
      {
        "lat" => "38.8977",
        "lon" => "-77.0365",
        "address" => { "postcode" => "20500" }
      }
    ].to_json

    client.stub(:http_get, OpenStruct.new(body: fake_body)) do
      res = client.geocode("1600 Pennsylvania Ave NW, Washington, DC 20500")
      assert_equal "38.8977", res[:lat]
      assert_equal "-77.0365", res[:lon]
      assert_equal "20500", res[:postal_code]
    end
  end

  test "geocode handles errors and returns nil" do
    client = Geocoding::Client.new
    client.stub(:http_get, ->(_uri) { raise Timeout::Error }) do
      res = client.geocode("any")
      assert_nil res
    end
  end
end
