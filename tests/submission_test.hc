import "../src/db"
import "../src/domain"
import "../src/proposal_hml"
import "../src/proposal_store"
import "../src/routes"
import "./fixtures"
import "sqlite"
import "testclient"
import "web"

test "submit initializes and persists canonical proposal" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let response = test_post(build_routes(db), "/v1/proposals/submit", valid_proposal_hml())

  assert(route_response_status(response) == 201)
  assert(contains(route_response_headers(response), "Content-Type: application/hml"))
  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.version == "1.0")
      assert(proposal.status == Submission)
      assert(length(proposal.history) == 1)
      match fetch_active_revision(db, proposal.proposal_id) {
        Ok(Some(stored)) => assert(stored.canonical_hml == route_response_body(response)),
        _ => assert(false)
      }
    }
  }
}

test "submit distinguishes malformed HML" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let response = test_post(build_routes(db), "/v1/proposals/submit", "@proposal(id: \"broken\"")

  assert(route_response_status(response) == 400)
  assert(contains(route_response_body(response), "\"code\": \"invalid_hml\""))
}

test "submit distinguishes invalid proposal structure" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let input = replace(
    valid_proposal_hml(),
    "  title: \"Migrate services to a trunk-based monorepo\"\n",
    ""
  )
  let response = test_post(build_routes(db), "/v1/proposals/submit", input)

  assert(route_response_status(response) == 400)
  assert(contains(route_response_body(response), "\"code\": \"invalid_proposal\""))
}

test "duplicate submission returns conflict without new revision" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let first = test_post(build_routes(db), "/v1/proposals/submit", valid_proposal_hml())
  let second = test_post(build_routes(db), "/v1/proposals/submit", valid_proposal_hml())

  assert(route_response_status(first) == 201)
  assert(route_response_status(second) == 409)
  assert(contains(route_response_body(second), "\"code\": \"proposal_exists\""))
  match fetch_revision_history(db, "PROP-042") {
    Ok(history) => assert(length(history) == 1),
    Err(_) => assert(false)
  }
}
