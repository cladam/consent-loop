import "web"
import "json"
import "sqlite"

pub fun api_error(status_code: int, code: string, message: string) {
  json_status(status_code, json_emit(JObject([
    ("error", JObject([
      ("code", JString(code)),
      ("message", JString(message))
    ]))
  ])))
}

pub fun handle_health(db, req) {
  match sqlite_query(db, "SELECT 1") {
    Ok(_) => json_response(json_emit(JObject([
      ("status", JString("ok")),
      ("db", JString("ok"))
    ]))),
    Err(_) => json_status(503, json_emit(JObject([
      ("status", JString("degraded")),
      ("db", JString("error"))
    ])))
  }
}

pub fun build_routes(db) {
  [get("/health", (req) => handle_health(db, req))]
}
