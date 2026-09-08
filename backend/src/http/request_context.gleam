import wisp

pub type RequestContext {
  RequestContext(request_id: String)
}

pub fn new() -> RequestContext {
  RequestContext(request_id: "req_" <> wisp.random_string(16))
}

pub fn request_id(context: RequestContext) -> String {
  context.request_id
}

pub fn add_request_id(
  response: wisp.Response,
  context: RequestContext,
) -> wisp.Response {
  wisp.set_header(response, "x-request-id", context.request_id)
}
