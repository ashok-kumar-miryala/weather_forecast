require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @address = "1600 Pennsylvania Ave NW, Washington, DC 20500"
  end

  test "should get index without params" do
    get forecasts_url
    assert_response :success
    assert_select "form"
  end

  test "should show forecast for address" do
    mock_result = ForecastService::Result.new(
      @address, "20500", 38.8977, -77.0365, 22.5, 28.0, 18.0, false, "mock"
    )
    mock_service = Object.new
    def mock_service.fetch(addr); @result; end
    mock_service.instance_variable_set(:@result, mock_result)

    ForecastService.stub :new, ->(*) { mock_service } do
      get forecasts_url, params: { address: @address }
    end

    assert_response :success
    assert_select "h2", text: "Forecast"
    assert_select "span", text: "cached", count: 0
  end

  test "shows cached indicator when from_cache is true" do
    mock_result = ForecastService::Result.new(
      @address, "20500", 38.8977, -77.0365, 22.5, 28.0, 18.0, true, "mock"
    )
    mock_service = Object.new
    def mock_service.fetch(addr); @result; end
    mock_service.instance_variable_set(:@result, mock_result)

    ForecastService.stub :new, ->(*) { mock_service } do
      get forecasts_url, params: { address: @address }
    end

    assert_response :success
    assert_select "span", text: "cached", count: 1
  end

  test "invalid input is handled gracefully" do
    mock_service = Object.new
    def mock_service.fetch(_addr); raise ForecastService::UserInputError, "Address cannot be blank."; end

    ForecastService.stub :new, ->(*) { mock_service } do
      get forecasts_url, params: { address: "" }
    end

    assert_response :success
    assert_select "div", /Error:/
  end
end