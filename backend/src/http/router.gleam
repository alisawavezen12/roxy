import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response
import http/handlers/health
import http/handlers/not_found
import mist

pub fn handle(request: Request(a)) -> response.Response(mist.ResponseData) {
  case request.method, request.path {
    http.Get, "/health" -> health.handle()
    _, _ -> not_found.handle()
  }
}
