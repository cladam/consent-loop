import "web"
import "sqlite"
import "./db"
import "./routes"

fun run_loop(server: int) : () {
  let _ = server_poll(server)
  run_loop(server)
}

fun main() {
  let db_path = match get_env("CONSENT_LOOP_DB_PATH") {
    Some(path) => path,
    None => "consent-loop.db"
  }
  match sqlite_open(db_path) {
    Err(error) => eprintln("failed to open database: " + error.message),
    Ok(db) => match init_db(db) {
      Err(error) => eprintln("failed to initialize database: " + error.message),
      Ok(_) => {
        let server = http_server_init(8080, (node) => {
          let request = request_from_id(node)
          let response = dispatch_routes_safe(request, build_routes(db))
          http_set_response(
            node,
            route_response_status(response),
            route_response_headers(response),
            route_response_body(response)
          )
        })
        println("ConsentLoop listening on http://localhost:8080")
        run_loop(server)
      }
    }
  }
}
