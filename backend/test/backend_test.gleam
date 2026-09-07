import backend/web
import gleeunit
import shared
import shared/health.{Health}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn healthy_database_returns_200_test() {
  let response =
    web.readiness_response(Health(ok: True, db: "ok", service: shared.app_name))
  assert response.status == 200
}

pub fn unavailable_database_returns_503_test() {
  let response =
    web.readiness_response(Health(ok: False, db: "error", service: shared.app_name))
  assert response.status == 503
}
