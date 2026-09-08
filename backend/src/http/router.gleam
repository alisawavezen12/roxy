import gleam/http
import http/handlers/health
import http/handlers/not_found
import wisp

pub fn handle(request: wisp.Request) -> wisp.Response {
  case request.method, request.path {
    http.Get, "/health" -> health.handle()
    _, _ -> not_found.handle()
  }
}
