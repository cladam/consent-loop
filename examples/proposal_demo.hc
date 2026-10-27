import "../src/db"
import "sqlite"

fun print_history(revisions: list<StoredRevision>) {
  match revisions {
    [] => {},
    [revision, ..rest] => {
      println(revision.version + " " + revision.status)
      print_history(rest)
    }
  }
}

fun main() {
  let db = unwrap(sqlite_open(":memory:"))
  let _ = init_db(db)
  let proposal_id = "DEMO-STORE-001"
  let _ = create_stored_proposal(db, proposal_id, "1.0", "submission", "@proposal(version: \"1.0\")")
  let _ = append_stored_revision(db, proposal_id, "1.1", "review", "@proposal(version: \"1.1\")")

  match fetch_active_revision(db, proposal_id) {
    Ok(Some(active)) => println("active: " + active.version),
    _ => eprintln("active proposal not found")
  }
  match fetch_revision_history(db, proposal_id) {
    Ok(revisions) => print_history(revisions),
    Err(error) => eprintln("history error: " + error.message)
  }
}
