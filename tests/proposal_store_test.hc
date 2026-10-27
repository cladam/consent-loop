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

test "failed duplicate revision preserves active proposal" {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal = unwrap(decode_proposal(valid_proposal_hml()))
  let next = Proposal { ...proposal, version: "1.2", status: Review }
  let conflict = Proposal { ...next, status: Passed, title: "Conflicting rewrite" }

  assert(is_ok(create_proposal(db, proposal)))
  assert(is_ok(append_revision(db, next)))
  assert(is_err(append_revision(db, conflict)))
  match fetch_active_revision(db, proposal.proposal_id) {
    Ok(Some(stored)) => {
      assert(stored.status == "review")
      assert(stored.canonical_hml == encode_proposal(next))
    },
    _ => assert(false)
  }
  match fetch_revision_history(db, proposal.proposal_id) {
    Ok(history) => assert(length(history) == 2),
    _ => assert(false)
  }
}
