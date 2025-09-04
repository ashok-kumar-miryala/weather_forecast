class ForecastsController < ApplicationController
  def index
    @address = params[:address].to_s.strip
    @result = nil
    @error_message = nil

    if @address.blank?
      @error_message = "Address cannot be blank."
      return
    end

    service = ForecastService.new(
      geocoding_client: Geocoding::Client.new,
      weather_client: Weather::Client.new
    )

    @result = service.fetch(@address)
  rescue ForecastService::UserInputError => e
    @error_message = e.message
  rescue StandardError => e
    Rails.logger.error("[ForecastsController] Unexpected error: #{e.class} - #{e.message}")
    @error_message = "Something went wrong while retrieving the forecast. Please try again later."
  end
end
