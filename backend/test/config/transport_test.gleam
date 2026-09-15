import application/messages
import config/environment
import config/origins
import config/transport
import envoy
import gleam/option
import gleeunit/should

pub fn development_allows_both_frontend_loopback_origins_test() {
  envoy.unset("CORS_ALLOWED_ORIGINS")
  origins.load(environment.Development)
  |> should.equal(
    Ok(
      origins.OriginsConfig(allowed: [
        "http://localhost:1234",
        "http://127.0.0.1:1234",
      ]),
    ),
  )
}

pub fn development_allows_http_base_url_test() {
  envoy.set("APP_ENV", "development")
  envoy.unset("PUBLIC_BASE_URL")
  envoy.unset("TRUSTED_PROXY_IPS")
  envoy.unset("TRUSTED_INTERNAL_IPS")

  transport.load(environment.Development)
  |> should.equal(
    Ok(
      transport.TransportConfig(
        public_base_url: "http://localhost:8080",
        trusted_proxy_ips: [],
        trusted_internal_ips: [],
      ),
    ),
  )
}

pub fn production_rejects_http_base_url_test() {
  envoy.set("PUBLIC_BASE_URL", "http://example.com")

  transport.load(environment.Production)
  |> should.equal(Error(messages.public_base_url_https_required))
}

pub fn production_requires_trusted_proxy_ips_test() {
  envoy.set("PUBLIC_BASE_URL", "https://example.com")
  envoy.unset("TRUSTED_PROXY_IPS")

  transport.load(environment.Production)
  |> should.equal(Error(messages.required_in_production("TRUSTED_PROXY_IPS")))
}

pub fn production_https_is_allowed_only_from_trusted_proxy_test() {
  let config =
    transport.TransportConfig(
      public_base_url: "https://example.com",
      trusted_proxy_ips: ["10.0.0.2"],
      trusted_internal_ips: ["172.18.0.2"],
    )

  transport.allows_request(
    environment.Production,
    config,
    "10.0.0.2",
    option.Some("https"),
  )
  |> should.equal(True)

  transport.allows_request(
    environment.Production,
    config,
    "203.0.113.5",
    option.Some("https"),
  )
  |> should.equal(False)

  transport.allows_request(
    environment.Production,
    config,
    "10.0.0.2",
    option.Some("http"),
  )
  |> should.equal(False)

  transport.allows_request(
    environment.Production,
    config,
    "172.18.0.2",
    option.None,
  )
  |> should.equal(True)
}
