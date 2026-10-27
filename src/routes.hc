import "web"
import "json"
import "sqlite"
import "./domain"
import "./proposal_hml"
import "./proposal_store"

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

pub fun handle_submit(db, req) {
  match decode_proposal(req_body(req)) {
    Err(ProposalSyntaxError(message)) => api_error(400, "invalid_hml", message),
    Err(ProposalValidationError(message)) => api_error(400, "invalid_proposal", message),
    Ok(proposal) => {
      let submission = initialize_submission(proposal)
      let canonical = encode_proposal(submission)
      match create_proposal(db, submission) {
        Ok(_) => content_response(201, "application/hml", canonical),
        Err(error) => if error.code == 1555 {
          api_error(409, "proposal_exists", "proposal already exists: " + submission.proposal_id)
        } else {
          api_error(500, "storage_error", "failed to store proposal")
        }
      }
    }
  }
}

pub fun build_routes(db) {
  [
    get("/health", (req) => handle_health(db, req)),
    post("/v1/proposals/submit", (req) => handle_submit(db, req))
  ]
}
