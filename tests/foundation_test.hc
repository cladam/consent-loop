import "../src/db"
import "../src/routes"
import "testclient"
import "sqlite"
import "web"

test "database bootstrap is idempotent" {
  let db = unwrap(sqlite_open(":memory:"))
  assert(is_ok(init_db(db)))
  assert(is_ok(init_db(db)))
  assert(is_ok(sqlite_query(db, "SELECT version FROM schema_migrations")))
}

test "GET health reports database readiness" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let response = test_get(build_routes(db), "/health")
  assert(route_response_status(response) == 200)
  let body = route_response_body(response)
  assert(contains(body, "\"status\": \"ok\""))
  assert(contains(body, "\"db\": \"ok\""))
}

test "API errors use the JSON envelope" {
  let routes = [get("/error", (req) => api_error(400, "invalid_request", "request is invalid"))]
  let response = test_get(routes, "/error")
  assert(route_response_status(response) == 400)
  let body = route_response_body(response)
  assert(contains(body, "\"error\""))
  assert(contains(body, "\"code\": \"invalid_request\""))
  assert(contains(body, "\"message\": \"request is invalid\""))
}
