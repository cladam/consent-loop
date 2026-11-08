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

test "evaluate adopts amendment bumping minor version and moving objector to consent" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let dissent = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "submission", dissent))

  let adopt = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"adopted\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let response = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "refinement", adopt))
  assert(route_response_status(response) == 200)

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.version == "1.1")
      assert(proposal.status == Refinement)
      assert(length(proposal.history) == 3)
      match fetch_active_revision(db, "PROP-042") {
        Ok(Some(stored)) => {
          assert(stored.version == "1.1")
          assert(stored.status == "refinement")
        },
        _ => assert(false)
      }
      match fetch_revision_history(db, "PROP-042") {
        Ok(history) => assert(length(history) == 3),
        _ => assert(false)
      }
    }
  }
}

test "evaluate adopted proposal transitions to passed upon consensus" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let dissent = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "submission", dissent))

  let adopt = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"adopted\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "refinement", adopt))

  let pass_input = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 2)"
  let response = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.1", "submission", pass_input))
  assert(route_response_status(response) == 200)

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.version == "1.1")
      assert(proposal.status == Passed)
      assert(length(proposal.history) == 4)
      match fetch_active_revision(db, "PROP-042") {
        Ok(Some(stored)) => {
          assert(stored.version == "1.1")
          assert(stored.status == "passed")
        },
        _ => assert(false)
      }
    }
  }
}

test "evaluate directional shift bumps major version and restarts review" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let dissent = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 0) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Architecture objection.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "submission", dissent))

  let shift = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 0) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"rejected\") \{\n" +
    "        Architecture objection.\n" +
    "      \}\n" +
    "    \}"
  let response = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "refinement", shift))
  assert(route_response_status(response) == 200)

  match decode_proposal(route_response_body(response)) {
    Err(_) => assert(false),
    Ok(proposal) => {
      assert(proposal.version == "2.0")
      assert(proposal.status == Review)
      assert(length(proposal.history) == 3)
      match fetch_active_revision(db, "PROP-042") {
        Ok(Some(stored)) => {
          assert(stored.version == "2.0")
          assert(stored.status == "review")
        },
        _ => assert(false)
      }
    }
  }
}

test "evaluate wrong version amendment returns 400" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let dissent = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "submission", dissent))

  let wrong = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"3.5\", status: \"adopted\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let response = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "refinement", wrong))
  assert(route_response_status(response) == 400)
  assert(contains(route_response_body(response), "\"code\": \"wrong_version_amendment\""))
}

test "evaluate already resolved amendment returns 409" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let routes = build_routes(db)
  let _ = test_post(routes, "/v1/proposals/submit", valid_proposal_hml())

  let dissent = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"proposed\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "submission", dissent))

  let adopt = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.0\", status: \"adopted\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let _ = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.0", "refinement", adopt))

  let adopt_again = "    @participant(user: \"alex\", level: 3)\n" +
    "    @participant(user: \"sofia\", level: 1) \{\n" +
    "      @amendment(target-version: \"1.1\", status: \"adopted\") \{\n" +
    "        Require package-level caching.\n" +
    "      \}\n" +
    "    \}"
  let response = test_post(routes, "/v1/proposals/evaluate", evaluation_proposal_hml("PROP-042", "1.1", "refinement", adopt_again))
  assert(route_response_status(response) == 409)
  assert(contains(route_response_body(response), "\"code\": \"already_resolved\""))
}
