import "web"
import "json"
import "sqlite"
import "./db"
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

pub fun current_timestamp(db) {
  match sqlite_query(db, "SELECT strftime('%Y-%m-%dT%H:%M:%SZ', 'now')") {
    Ok(result) => match result.rows {
      [row, .._] => unwrap_maybe_or(row_str(row, 0), "2026-01-01T00:00:00Z"),
      [] => "2026-01-01T00:00:00Z"
    },
    Err(_) => "2026-01-01T00:00:00Z"
  }
}

pub fun resolve_transition_timestamp(incoming: Proposal, default_time: string) : string {
  match last(incoming.history) {
    None => default_time,
    Some(rev) => if rev.event != "submitted" && rev.timestamp != "" {
      rev.timestamp
    } else {
      default_time
    }
  }
}

pub fun handle_evaluate(db, req) {
  match decode_proposal(req_body(req)) {
    Err(ProposalSyntaxError(message)) => api_error(400, "invalid_hml", message),
    Err(ProposalValidationError(message)) => api_error(400, "invalid_proposal", message),
    Ok(incoming) => match fetch_active_revision(db, incoming.proposal_id) {
      Err(_) => api_error(500, "storage_error", "failed to read proposal"),
      Ok(None) => api_error(404, "proposal_not_found", "proposal not found: " + incoming.proposal_id),
      Ok(Some(stored)) => match decode_proposal(stored.canonical_hml) {
        Err(_) => api_error(500, "storage_error", "failed to decode stored proposal"),
        Ok(active) => {
          let timestamp = resolve_transition_timestamp(incoming, current_timestamp(db))
          match evaluate_proposal_transition(active, incoming, timestamp) {
            Err(MissingComfortAmendment(user)) =>
              api_error(400, "invalid_proposal", "participant '" + user + "' requires an amendment at Level 0 or Level 1"),
            Err(ProposalIdMismatch(_, actual)) =>
              api_error(400, "id_mismatch", "mismatched proposal id: " + actual),
            Err(StaleVersionMismatch(expected, actual)) =>
              api_error(409, "stale_version", "expected version " + expected + " but received " + actual),
            Err(IllegalStatusTransition(from_s, to_s)) =>
              api_error(409, "illegal_transition", "cannot transition proposal from " + from_s + " to " + to_s),
            Err(WrongVersionAmendment(target_v, expected_v)) =>
              api_error(400, "wrong_version_amendment", "amendment target version " + target_v + " does not match proposal version " + expected_v),
            Err(AlreadyResolvedAmendment(user)) =>
              api_error(409, "already_resolved", "amendment for participant '" + user + "' is already resolved"),
            Err(AmbiguousAmendment(message)) =>
              api_error(400, "ambiguous_amendment", message),
            Ok(transitioned) => {
              let canonical = encode_proposal(transitioned)
              match append_revision(db, transitioned) {
                Ok(_) => content_response(200, "application/hml", canonical),
                Err(_) => api_error(500, "storage_error", "failed to store revision")
              }
            }
          }
        }
      }
    }
  }
}

pub fun build_routes(db) {
  [
    get("/health", (req) => handle_health(db, req)),
    post("/v1/proposals/submit", (req) => handle_submit(db, req)),
    post("/v1/proposals/evaluate", (req) => handle_evaluate(db, req))
  ]
}
