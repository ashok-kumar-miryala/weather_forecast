class ForecastService
  class UserInputError < StandardError; end

  Result = Struct.new(
    :address,          # input address
    :zip,              # normalized ZIP (first 5 digits)
    :latitude,         # Float
    :longitude,        # Float
    :current_temp_c,   # Float (Celsius)
    :daily_high_c,     # Float (Celsius, today)
    :daily_low_c,      # Float (Celsius, today)
    :from_cache,       # Boolean
    :source            # String describing the provider(s)
  )

  CACHE_TTL = 30.minutes
  ZIP_REGEX = /\b(\d{5})(?:-\d{4})?\b/

  def initialize(geocoding_client:, weather_client:)
    @geocoding_client = geocoding_client
    @weather_client = weather_client
  end

  # Public API: Fetch forecast for a given address.
  # Returns a Result struct or raises UserInputError for invalid input.
  def fetch(address)
    raise UserInputError, "Address cannot be blank." if address.blank?

    zip = extract_zip(address)

    if zip
      cached = read_cache(zip)
      return cached if cached
    end

    geo = @geocoding_client.geocode(address)
    unless geo && geo[:lat] && geo[:lon]
      raise UserInputError, "Unable to geocode the provided address. Please provide a more specific address."
    end

    zip ||= normalize_zip(geo[:postal_code])

    # If we now have a ZIP from geocoding, check cache again before fetching weather.
    if zip
      cached = read_cache(zip)
      return cached if cached
    end

    weather = @weather_client.fetch_current_and_daily(lat: geo[:lat], lon: geo[:lon])

    result = Result.new(
      address,
      zip,
      geo[:lat].to_f,
      geo[:lon].to_f,
      weather[:current_temp_c],
      weather[:daily_high_c],
      weather[:daily_low_c],
      false,
      "Geocoding: #{geo[:provider]}; Weather: #{weather[:provider]}"
    )

    write_cache(zip, result) if zip.present?

    result
  end

  private

  def extract_zip(address)
    m = address.to_s.match(ZIP_REGEX)
    normalize_zip(m && m[1])
  end

  def normalize_zip(zip_candidate)
    return nil if zip_candidate.blank?
    zip_candidate.to_s[0, 5]
  end

  def cache_key(zip)
    "forecast:zip:#{zip}"
  end

  def read_cache(zip)
    return nil if zip.blank?
    cached = Rails.cache.read(cache_key(zip))
    return nil if cached.nil?

    address = cached.respond_to?(:address) ? cached.address : cached[:address]
    cached_zip = cached.respond_to?(:zip) ? cached.zip : cached[:zip]
    latitude = cached.respond_to?(:latitude) ? cached.latitude : cached[:latitude]
    longitude = cached.respond_to?(:longitude) ? cached.longitude : cached[:longitude]
    current_temp_c = cached.respond_to?(:current_temp_c) ? cached.current_temp_c : cached[:current_temp_c]
    daily_high_c = cached.respond_to?(:daily_high_c) ? cached.daily_high_c : cached[:daily_high_c]
    daily_low_c = cached.respond_to?(:daily_low_c) ? cached.daily_low_c : cached[:daily_low_c]
    source = cached.respond_to?(:source) ? cached.source : cached[:source]

    Result.new(
      address,
      cached_zip || zip,
      latitude,
      longitude,
      current_temp_c,
      daily_high_c,
      daily_low_c,
      true,
      source
    )
  end

  def write_cache(zip, result)
    return if zip.blank? || result.nil?
    Rails.cache.write(cache_key(zip), result, expires_in: CACHE_TTL)
  end
end
