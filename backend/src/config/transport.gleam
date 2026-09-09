import config/defaults
import config/environment
import envoy
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{Uri}

pub type TransportConfig {
  TransportConfig(
    public_base_url: String,
    trusted_proxy_ips: List(String),
    trusted_internal_ips: List(String),
  )
}

pub fn load(
  environment: environment.Environment,
) -> Result(TransportConfig, String) {
  use public_base_url <- result.try(load_public_base_url(environment))
  use trusted_proxy_ips <- result.try(load_trusted_proxy_ips(environment))
  use trusted_internal_ips <- result.try(load_trusted_internal_ips(environment))
  Ok(TransportConfig(
    public_base_url:,
    trusted_proxy_ips:,
    trusted_internal_ips:,
  ))
}

pub fn public_https(config: TransportConfig) -> Bool {
  string.starts_with(string.lowercase(config.public_base_url), "https://")
}

pub fn trusted_proxy(config: TransportConfig, peer_ip: String) -> Bool {
  list.contains(config.trusted_proxy_ips, peer_ip)
}

pub fn allows_request(
  environment: environment.Environment,
  config: TransportConfig,
  peer_ip: String,
  forwarded_proto: option.Option(String),
) -> Bool {
  case environment {
    environment.Development -> True
    environment.Production ->
      case forwarded_proto {
        option.Some("https") -> trusted_proxy(config, peer_ip)
        _ -> list.contains(config.trusted_internal_ips, peer_ip)
      }
  }
}

fn load_public_base_url(
  environment: environment.Environment,
) -> Result(String, String) {
  let value = case envoy.get("PUBLIC_BASE_URL") {
    Ok(value) ->
      case string.trim(value) {
        "" -> missing_base_url(environment)
        trimmed -> Ok(trimmed)
      }
    Error(_) ->
      case environment {
        environment.Development -> Ok(defaults.public_base_url)
        environment.Production ->
          Error(
            "PUBLIC_BASE_URL environment variable is required in production",
          )
      }
  }
  use value <- result.try(value)
  validate_public_base_url(environment, value)
}

fn load_trusted_proxy_ips(
  environment: environment.Environment,
) -> Result(List(String), String) {
  case envoy.get("TRUSTED_PROXY_IPS") {
    Ok(value) ->
      case string.trim(value) {
        "" -> missing_proxy_ips(environment)
        _ -> parse_proxy_ips(value)
      }
    Error(_) ->
      case environment {
        environment.Development -> Ok([])
        environment.Production ->
          Error(
            "TRUSTED_PROXY_IPS environment variable is required in production",
          )
      }
  }
}

fn missing_base_url(
  environment: environment.Environment,
) -> Result(String, String) {
  case environment {
    environment.Development -> Ok(defaults.public_base_url)
    environment.Production ->
      Error("PUBLIC_BASE_URL environment variable is required in production")
  }
}

fn missing_proxy_ips(
  environment: environment.Environment,
) -> Result(List(String), String) {
  case environment {
    environment.Development -> Ok([])
    environment.Production ->
      Error("TRUSTED_PROXY_IPS environment variable is required in production")
  }
}

fn load_trusted_internal_ips(
  environment: environment.Environment,
) -> Result(List(String), String) {
  case envoy.get("TRUSTED_INTERNAL_IPS") {
    Ok(value) ->
      case string.trim(value) {
        "" -> missing_internal_ips(environment)
        _ -> parse_proxy_ips(value)
      }
    Error(_) -> missing_internal_ips(environment)
  }
}

fn missing_internal_ips(
  environment: environment.Environment,
) -> Result(List(String), String) {
  case environment {
    environment.Development -> Ok([])
    environment.Production ->
      Error(
        "TRUSTED_INTERNAL_IPS environment variable is required in production",
      )
  }
}

fn parse_proxy_ips(value: String) -> Result(List(String), String) {
  let ips = value |> string.split(",") |> list.map(string.trim)
  case list.any(ips, fn(ip) { ip == "" }) {
    True -> Error("TRUSTED_PROXY_IPS must not contain empty entries")
    False -> Ok(ips)
  }
}

fn validate_public_base_url(
  environment: environment.Environment,
  value: String,
) -> Result(String, String) {
  case uri.parse(value) {
    Ok(Uri(scheme: option.Some(scheme), host: option.Some(host), ..))
      if host != ""
    -> {
      let scheme = string.lowercase(scheme)
      case environment, scheme {
        environment.Development, "http" -> Ok(value)
        environment.Development, "https" -> Ok(value)
        environment.Production, "https" -> Ok(value)
        environment.Production, _ ->
          Error("PUBLIC_BASE_URL must use https:// outside development")
        _, _ -> Error("PUBLIC_BASE_URL must use http:// or https://")
      }
    }
    _ -> Error("PUBLIC_BASE_URL must be an absolute http(s) URL")
  }
}
