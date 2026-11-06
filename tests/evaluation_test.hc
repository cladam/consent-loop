import "../src/db"
import "../src/domain"
import "../src/proposal_hml"
import "../src/proposal_store"
import "../src/routes"
import "./fixtures"
import "sqlite"
import "testclient"
import "web"

test "evaluate all comfortable transitions to passed" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let participants = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 2)"
  let eval_input = evaluation_proposal_hml("PROP-042", "1.0", "submission", participants)

  let response = test_post(routes, "/v1/proposals/evaluate", eval_input)
  assert(route_response_status(response) == 200)
  assert(contains(route_response_headers(response), "Content-Type: application/hml"))

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.status == Passed)
      assert(proposal.version == "1.0")
      assert(length(proposal.history) == 2)
      match fetch_active_revision(db, "PROP-042") {
        Ok(Some(stored)) => {
          assert(stored.status == "passed")
          assert(stored.version == "1.0")
        },
        _ => assert(false)
      }
      match fetch_revision_history(db, "PROP-042") {
        Ok(history) => assert(length(history) == 2),
        _ => assert(false)
      }
    }
  }
}

test "evaluate hesitant participant transitions to refinement" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let participants = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let eval_input = evaluation_proposal_hml("PROP-042", "1.0", "submission", participants)

  let response = test_post(routes, "/v1/proposals/evaluate", eval_input)
  assert(route_response_status(response) == 200)

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.status == Refinement)
      assert(length(proposal.history) == 2)
      match fetch_active_revision(db, "PROP-042") {
        Ok(Some(stored)) => assert(stored.status == "refinement"),
        _ => assert(false)
      }
    }
  }
}

test "evaluate transitions submission to review explicitly" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let participants = "    @participant(user: \"alex\", level: 3)"
  let eval_input = evaluation_proposal_hml("PROP-042", "1.0", "review", participants)

  let response = test_post(routes, "/v1/proposals/evaluate", eval_input)
  assert(route_response_status(response) == 200)

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.status == Review)
      assert(length(proposal.history) == 2)
    }
  }
}

test "evaluate unknown proposal returns 404" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)

  let participants = "    @participant(user: \"alex\", level: 3)"
  let eval_input = evaluation_proposal_hml("NONEXISTENT", "1.0", "submission", participants)

  let response = test_post(routes, "/v1/proposals/evaluate", eval_input)
  assert(route_response_status(response) == 404)
  assert(contains(route_response_body(response), "\"code\": \"proposal_not_found\""))
}

test "evaluate with stale version returns 409" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let participants = "    @participant(user: \"alex\", level: 3)"
  let eval_input = evaluation_proposal_hml("PROP-042", "0.9", "submission", participants)

  let response = test_post(routes, "/v1/proposals/evaluate", eval_input)
  assert(route_response_status(response) == 409)
  assert(contains(route_response_body(response), "\"code\": \"stale_version\""))
}
