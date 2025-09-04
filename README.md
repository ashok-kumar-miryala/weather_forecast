# Weather Forecast

This application allows users to input an address and retrieve the current temperature and today's high/low. Results are cached by ZIP code for 30 minutes, and the UI displays when results are served from cache.

Features
- Address input (free form)
- Forecast retrieval:
  - Current temperature (°C)
  - Today's high/low (°C)
- Caching:
  - Cache keyed by 5-digit ZIP for 30 minutes
  - UI shows a "cached" badge when served from cache
- Tests:
  - Unit tests for the service, controller, and adapters
- Documentation and design notes below

Requirements
- Ruby 3.3.9
- Rails 8.x
- Bundler 2.5.x

Getting Started
1. Install dependencies:
  - bundle install
2. Run the server:
  - bin/rails server
3. Open in browser:
  - http://localhost:3000
4. Enter an address (e.g., “1600 Pennsylvania Ave NW, Washington, DC 20500”) and submit.

Configuration
- Caching is configured via config/cache.yml. Default store should be fine for development/test. In production, ensure a robust cache store (e.g., Redis).
- External Services:
  - Geocoding: Nominatim (OpenStreetMap)
  - Weather: Open-Meteo
- Optional env var:
  - GEOCODING_USER_AGENT: Customize the User-Agent header for Nominatim usage policy.

Testing
- Run tests:
  - bin/rails test
- The test suite stubs network calls for repeatability and speed.

Decomposition of Objects
- ForecastsController
  - Minimal controller: receives user input, invokes ForecastService, renders results or errors.
- ForecastService (Orchestrator)
  - Extracts ZIP from address.
  - Delegates geocoding to Geocoding::Client.
  - Delegates weather retrieval to Weather::Client.
  - Caches by ZIP for 30 minutes with Rails.cache.
  - Returns a Result struct with a from_cache flag.
- Geocoding::Client (Adapter)
  - Talks to Nominatim to resolve address -> { lat, lon, postal_code }.
  - Error tolerant: returns nil on failure.
- Weather::Client (Adapter)
  - Talks to Open-Meteo to resolve { lat, lon } -> temps (current, high, low).
  - Error tolerant: returns nil temps on failure.
- Views (forecasts/index.html.erb)
  - Simple form and result rendering with a cached indicator.

Design Patterns Applied
- Adapter Pattern:
  - Geocoding::Client and Weather::Client abstract external service details behind a stable interface. They can be replaced with different providers without changing business logic.
- Service Object:
  - ForecastService encapsulates orchestration and business rules (ZIP normalization, caching policy).
- Value Object:
  - ForecastService::Result is an immutable-like struct passed to the presentation layer.

Scalability Considerations
- Caching:
  - Cache by ZIP significantly reduces repeated calls for popular areas. Use Redis or Memcached in production for multi-node deployments.
- Rate Limits:
  - External services can rate limit. Consider:
    - Circuit breakers (e.g., using a gem like stoplight or implementing a simple breaker).
    - Request throttling and backoff.
    - Adding a secondary provider and failover strategy.
- Observability:
  - Log slow requests and external errors (already logging warnings). Consider metrics for cache hit ratio and external call latency.
- Resilience:
  - Weather::Client returns nil values on failure to avoid breaking the page; the UI displays “N/A”.

Naming Conventions
- Classes and modules use descriptive, enterprise-ready names (ForecastService, Geocoding::Client, Weather::Client).
- Methods are single-purpose and named by intent (fetch, geocode, fetch_current_and_daily).

Encapsulation and Code Reuse
- Each class has a single responsibility:
  - Controller: HTTP and view coordination.
  - Service: business logic and caching.
  - Clients: API interaction.
- Swappable clients via constructor injection allow reuse and testing without network dependency.

Error Handling
- User-friendly errors on invalid address input or when geocoding fails.
- Defensive programming against external API failures with logs and safe fallbacks.

Security and Compliance
- Respect Nominatim’s usage policy. Provide a real contact in GEOCODING_USER_AGENT for production.
- Avoid storing personal addresses in logs in production; log minimal necessary info.

Future Enhancements
- Support units (C/F) per user preference.
- Show multi-day extended forecasts.
- Autocomplete addresses and validate ZIP codes client-side.
- Persist popular ZIPs and pre-warm cache.