import config/environment
import config/transport
import gleam/http/request
import gleam/option
import gleam/string
import mist

pub fn allows(
  http_request: request.Request(mist.Connection),
  config: transport.TransportConfig,
  environment: environment.Environment,
) -> Bool {
  let peer_ip = case mist.get_connection_info(http_request.body) {
    Ok(info) -> mist.ip_address_to_string(info.ip_address)
    Error(_) -> ""
  }
  let forwarded_proto = case
    request.get_header(http_request, "x-forwarded-proto")
  {
    Ok(value) -> option.Some(value |> string.lowercase |> string.trim)
    Error(_) -> option.None
  }
  transport.allows_request(environment, config, peer_ip, forwarded_proto)
}
