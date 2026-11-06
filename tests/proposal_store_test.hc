import "../src/db"
import "../src/domain"
import "../src/proposal_hml"
import "../src/proposal_store"
import "./fixtures"
import "sqlite"

test "create and fetch active proposal revision" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = unwrap(decode_proposal(valid_proposal_hml()))
  let canonical = encode_proposal(proposal)

  assert(is_ok(create_proposal(db, proposal)))
  match fetch_active_revision(db, proposal.proposal_id) {
    Err(_) => assert(false),
    Ok(None) => assert(false),
    Ok(Some(stored)) => {
      assert(stored.version == proposal.version)
      assert(stored.status == "refinement")
      assert(stored.canonical_hml == canonical)
    }
  }
}

test "reject duplicate proposal ids" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = unwrap(decode_proposal(valid_proposal_hml()))

  assert(is_ok(create_proposal(db, proposal)))
  assert(is_err(create_proposal(db, proposal)))
  match fetch_revision_history(db, proposal.proposal_id) {
    Ok([stored]) => assert(stored.version == proposal.version),
    _ => assert(false)
  }
}

test "append revision updates active proposal and ordered history" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = unwrap(decode_proposal(valid_proposal_hml()))
  let next = Proposal { ...proposal, version: "1.2", status: Review }

  assert(is_ok(create_proposal(db, proposal)))
  assert(is_ok(append_revision(db, next)))
  match fetch_active_revision(db, proposal.proposal_id) {
    Ok(Some(stored)) => {
      assert(stored.version == "1.2")
      assert(stored.status == "review")
      assert(stored.canonical_hml == encode_proposal(next))
    },
    _ => assert(false)
  }
  match fetch_revision_history(db, proposal.proposal_id) {
    Ok([first, second]) => {
      assert(first.version == "1.1")
      assert(second.version == "1.2")
    },
    _ => assert(false)
  }
}

test "same-version status transitions are stored immutably" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let initial = unwrap(decode_proposal(valid_proposal_hml()))
  let initial_v1 = Proposal { ...initial, version: "1.0", status: Submission }
  let review_v1 = Proposal { ...initial_v1, status: Review }
  let passed_v1 = Proposal { ...initial_v1, status: Passed }

  assert(is_ok(create_proposal(db, initial_v1)))
  assert(is_ok(append_revision(db, review_v1)))
  assert(is_ok(append_revision(db, passed_v1)))

  match fetch_active_revision(db, initial_v1.proposal_id) {
    Ok(Some(stored)) => {
      assert(stored.version == "1.0")
      assert(stored.status == "passed")
      assert(stored.canonical_hml == encode_proposal(passed_v1))
    },
    _ => assert(false)
  }
  match fetch_revision_history(db, initial_v1.proposal_id) {
    Ok([first, second, third]) => {
      assert(first.version == "1.0" && first.status == "submission")
      assert(second.version == "1.0" && second.status == "review")
      assert(third.version == "1.0" && third.status == "passed")
    },
    _ => assert(false)
  }
}

test "append revision to non-existent proposal fails" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = unwrap(decode_proposal(valid_proposal_hml()))

  assert(is_err(append_revision(db, proposal)))
}
